// #![deny(warnings)]
use bytes::{BufMut, BytesMut};
use chrono::Utc;
use futures::StreamExt;
use futures::TryStreamExt;
use kv::{Config, Store};
use serde_json::json;
use std::collections::HashMap;
use std::convert::Infallible;
use std::env;
use std::fs::create_dir;
use std::path::Path;
use std::sync::Arc;
use tokio::sync::{mpsc, RwLock};
use uuid::Uuid;
use warp::ws::{Message, WebSocket};
use warp::{
    http::StatusCode,
    multipart::{FormData, Part},
    Filter, Rejection, Reply,
};

type ConnectedUsers =
    Arc<RwLock<HashMap<Uuid, mpsc::UnboundedSender<Result<Message, warp::Error>>>>>;

#[tokio::main]
async fn main() {
    pretty_env_logger::init();

    let uploads_dir = "uploads";
    if !Path::new(uploads_dir).is_dir() {
        create_dir(uploads_dir).expect("Could not create uploads dir");
    }
    dotenv::dotenv().ok();

    let port = env::var("PORT")
        .map(|p| p.parse().unwrap_or(3030))
        .unwrap_or(3030);

    let users = ConnectedUsers::default();
    let cfg = Config::new("./database");
    let store = Store::new(cfg).expect("Could not create database");
    let store = warp::any().map(move || store.clone());
    let users = warp::any().map(move || users.clone());

    let chat = warp::path("chat")
        .and(warp::ws())
        .and(users.clone())
        .and(store.clone())
        .map(|ws: warp::ws::Ws, users, store| {
            ws.on_upgrade(move |socket| user_connected(socket, users, store))
        });

    let upload_route = warp::path("upload")
        .and(users)
        .and(store.clone())
        .and(warp::post())
        .and(warp::multipart::form().max_length(5_000_000))
        .and_then(upload);
    let view_uploads_route = warp::path(uploads_dir).and(warp::fs::dir("uploads"));

    // Static stuff
    let assets = warp::path("public").and(warp::fs::dir("assets/public/dist"));
    let index = warp::fs::file("assets/public/dist/index.html");

    let routes = upload_route
        .or(view_uploads_route)
        .or(chat)
        .or(assets)
        .or(index)
        .recover(handle_rejection);

    warp::serve(routes).run(([0, 0, 0, 0], port)).await;
}

async fn user_connected(ws: WebSocket, users: ConnectedUsers, store: Store) {
    let my_id = Uuid::new_v4();
    let (user_ws_tx, mut user_ws_rx) = ws.split();
    let (tx, rx) = mpsc::unbounded_channel();

    tokio::task::spawn(rx.forward(user_ws_tx));

    // Save id and send end
    users.write().await.insert(my_id, tx.clone());

    let mut ids = vec![];
    for (id, _) in users.read().await.iter() {
        ids.push(id.clone());
    }

    // Let everyone know someone new is in town
    let value = json!({ "users": ids });
    let msg = serde_json::to_string(&value).unwrap();
    broadcast(&users, Message::text(msg)).await;

    // Set up bucket for room messages
    let bucket = store.bucket::<String, String>(Some("messages")).unwrap();

    // Send existing messages to user
    for item in bucket.iter() {
        let item = item.unwrap();
        let value = item.value::<String>().unwrap();
        let msg = Message::text(value);
        let _ = tx.send(Ok(msg));
    }

    // Receive messages
    while let Some(Ok(msg)) = user_ws_rx.next().await {
        // Store the message
        let message_key = format!("{}{}", Utc::now().naive_utc(), my_id);
        if let Ok(txt) = msg.to_str() {
            bucket.set(message_key, txt).unwrap();
        }

        broadcast(&users, msg).await
    }

    // If we are out of the loop remove this client
    users.write().await.remove(&my_id);
}

/// Upload handler
async fn upload(
    users: ConnectedUsers,
    store: Store,
    form: FormData,
) -> Result<impl Reply, Rejection> {
    // Set up bucket for messages
    let bucket = store.bucket::<String, String>(Some("messages")).unwrap();

    let parts: Vec<Part> = form
        .try_collect()
        .await
        .map_err(|_| warp::reject::reject())?;

    let mut urls = vec![];

    for p in parts {
        if p.name() == "files[]" {
            let content_type = p.content_type();
            let file_ending = match content_type {
                Some(file_type) => match file_type {
                    "image/png" => "png",
                    "image/jpeg" => "jpeg",
                    "image/jpg" => "jpg",
                    _ => {
                        return Err(warp::reject::reject());
                    }
                },
                None => {
                    return Err(warp::reject::reject());
                }
            };

            let value = p
                .stream()
                .try_fold(BytesMut::new(), |mut vec, data| {
                    vec.put(data);
                    async move { Ok(vec) }
                })
                .await
                .map_err(|_| warp::reject::reject())?;

            let file_name = format!("{}.{}", Uuid::new_v4().to_string(), file_ending);
            let path = format!("./uploads/{}", file_name);
            let url = format!("/uploads/{}", file_name);
            urls.push(url);

            tokio::fs::write(&path, value)
                .await
                .map_err(|_| warp::reject::reject())?;
        }
    }

    let value = json!({ "uploaded": urls });
    let msg = serde_json::to_string(&value).unwrap();
    let msg = Message::text(msg);

    // Store the message
    let message_key = format!("{}{}", Utc::now().naive_utc(), "uploads");
    let txt = msg.to_str().unwrap();
    bucket.set(message_key, txt).unwrap();

    broadcast(&users, msg).await;

    Ok("success")
}

async fn handle_rejection(err: Rejection) -> std::result::Result<impl Reply, Infallible> {
    let (code, message) = if err.is_not_found() {
        (StatusCode::NOT_FOUND, "Not Found".to_string())
    } else if err.find::<warp::reject::PayloadTooLarge>().is_some() {
        (StatusCode::BAD_REQUEST, "Payload too large".to_string())
    } else {
        eprintln!("unhandled error: {:?}", err);
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Internal Server Error".to_string(),
        )
    };

    Ok(warp::reply::with_status(message, code))
}

async fn broadcast(users: &ConnectedUsers, msg: Message) {
    for (_, tx) in users.read().await.iter() {
        let _ = tx.send(Ok(msg.clone()));
    }
}
