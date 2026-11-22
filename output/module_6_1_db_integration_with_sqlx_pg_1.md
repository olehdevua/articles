## Phase 1: Rust Foundations (6 modules) - From Zero To Polkadot Hero

# 🦀Module 6.1: Database Integration with SQLx + Postgres

## Querying, Transactions, and Data Modeling

Welcome back 👋!
In [Part 1](https://medium.com/@ed.wacc1995/module-6-project-rust-rest-api-013c949a768e) ,
we built a tiny Axum API with a `/health` endpoint.
Now, it's time to **connect our API to a real database** - Postgres - using **SQLx** .

By the end of this post, you'll have:
✅ A `users` table in Postgres
✅ Database migrations
✅ Axum endpoints to insert and query users

### Step 1 - Add dependencies

Update `Cargo.toml` to include `sqlx` + Postgres driver:

```toml
# Already from Part 1
[dependencies]
tokio = { version = "1.47.1" , features = [ "full" ] }
axum =  { version = "0.8.5" , features = [ "json" ] }
serde = { version = "1.0.228" , features = [ "derive" ] }
serde_json = "1.0.145"
tracing = "0.1.41"
tracing-subscriber = { version = "0.3.20" , features = [ "fmt" , "env-filter" ] }
dotenvy = "0.15.7"

# NEW
sqlx = { version = "0.8.6" , features = [ "runtime-tokio-rustls" , "postgres" , "macros" , "uuid" ] }
uuid = { version = "1.18.1" , features = [ "serde" , "v4" ] }
thiserror = { version = "2.0.17" }
```

We're enabling:

- `postgres` → Postgres driver
- `runtime-tokio-rustls` → async runtime
- `macros` → compile-time SQL checking
- `uuid` → generate user IDs

### Step 2 - Setup Postgres locally

If you're using [Docker](https://docs.docker.com/engine/install/) , spin up Postgres like this:

```
docker run --name rust-postgres -e POSTGRES_PASSWORD=secret -p 5432:5432 -d postgres:16
```

There is a [VS Code extension](https://code.visualstudio.com/docs/containers/overview) that could help interact with containers.

👉 Credentials:

- user: `postgres`
- password: `secret`
- db: `postgres`

### Step 3 - Configure .env

Add to the `.env` file at the root of the project:

```shell
DATABASE_URL=postgres://postgres:secret@localhost:5432/postgres
```

### Step 4 - Initialize SQLx migrations

Run:

```
cargo install sqlx-cli --no-default-features --features native-tls,postgres
sqlx migrate add create_users
```

This creates a new migration file under `migrations/` . Open it and define the `users` table:

```sql
-- migrations/<timestamp>_create_users.sql
CREATE TABLE users
(
  id    UUID PRIMARY KEY,
  name  TEXT        NOT NULL,
  email TEXT UNIQUE NOT NULL
);
```

Apply it:

```bash
sqlx migrate run --database-url postgres://postgres:secret@localhost:5432/postgres
```

## Project Layout

```
.
├── Cargo.toml
├── migrations
│   └── 20250930134717_create_users.sql
└── src
├── main.rs # entrypoint
├── routes.rs # all HTTP routes
├── handlers.rs # logic for handling requests
├── models.rs # database models (User, CreateUser, etc.)
└── db.rs # database pool and setup
```

### Step 1- Create db.rs (database setup)

```rust
// src/db.rs
use sqlx::{Pool, Postgres};

pub type DbPool = Pool<Postgres>;

pub async fn connect (database_url: & str ) -> DbPool {
Pool::<Postgres>:: connect (database_url)
. await
. expect ( "Failed to connect to Postgres" )
}
```

At main.rs you shall be adding **mod db;** just below the imports, that way the rust analyzer can help with intellisense

### Step 2 - src/models.rs - Data models / DTOs

```rust
// src/models.rs
use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use uuid::Uuid;

#[derive(Serialize, FromRow)]
pub struct User {
pub id: Uuid,
pub name: String ,
pub email: String ,
}

#[derive(Deserialize)]
pub struct CreateUser {
pub name: String ,
pub email: String ,
}

#[derive(Serialize)]
pub struct HealthResponse {
pub status: String ,
}
```

### Step 3 - src/handlers.rs - Request handlers + AppState

```rust
// src/handlers.rs
use axum::{extract::State, Json};
use uuid::Uuid;

use crate::db::DbPool;
use crate::models::{CreateUser, HealthResponse, User};
use sqlx;

#[derive(Clone)]
pub struct AppState {
pub db: DbPool,
}

pub async fn health () -> Json<HealthResponse> {
Json (HealthResponse {
status: "ok" . to_string (),
})
}

pub async fn root () -> & 'static str {
"Hello, Backend Engineer!"
}

pub async fn create_user (
State (state): State<AppState>,
Json (payload): Json<CreateUser>,
) -> Result <Json<User>, (axum::http::StatusCode, String )> {
let id = Uuid:: new_v4 ();
let res = sqlx::query_as::<_, User>(
"INSERT INTO users (id, name, email) VALUES ($1, $2, $3) RETURNING id, name, email" ,
)
. bind (id)
. bind (&payload.name)
. bind (&payload.email)
. fetch_one (&state.db)
. await ;

match res {
Ok (user) => Ok ( Json (user)),
Err (err) => {
// basic error mapping; improve in Part 3
let msg = format! ( "DB error: {}" , err);
Err ((axum::http::StatusCode::INTERNAL_SERVER_ERROR, msg))
}
}
}

pub async fn list_users (
State (state): State<AppState>,
) -> Result <Json< Vec <User>>, (axum::http::StatusCode, String )> {
let res = sqlx::query_as::<_, User>( "SELECT id, name, email FROM users" )
. fetch_all (&state.db)
. await ;

match res {
Ok (users) => Ok ( Json (users)),
Err (err) => Err ((axum::http::StatusCode::INTERNAL_SERVER_ERROR, format! ( "DB error: {}" , err))),
}
}
```

Note: handlers return `Result<..., (StatusCode, String)>` for basic error responses - we'll refine error handling in a future post

### Step 4 - src/routes.rs - Router factory

```
// src/routes.rs
use axum::{routing::{get, post}, Router};

use crate::handlers::{create_user, health, list_users, root, AppState};

pub fn create_router (state: AppState) -> Router {
Router:: new ()
. route ( "/" , get (root))
. route ( "/health" , get (health))
. route ( "/users" , post (create_user). get (list_users))
. with_state (state)
}
```

### Step 5 - src/main.rs - Program entrypoint

```rust
// src/main.rs
// use statements are like saying "I'm going to use these tools from my toolbox."
use dotenvy::dotenv;
use std::env;
use std::net::SocketAddr;
use tokio::net::TcpListener;
use tracing_subscriber;

mod db;
mod handlers;
mod models;
mod routes;

use db::connect;
use handlers::AppState;
use routes::create_router;

#[tokio::main]
async fn main () {
dotenv (). ok ();
tracing_subscriber:: fmt ()
. with_env_filter ( "rust_rest_api=debug,tower_http=debug" )
. init ();

let database_url = env:: var ( "DATABASE_URL" ). expect ( "DATABASE_URL not set" );
let pool = connect (&database_url). await ;

let state = AppState { db: pool };
let app = create_router (state);

let port : u16 = env:: var ( "PORT" )
. unwrap_or_else (|_| "3000" . to_string ())
. parse ()
. expect ( "PORT must be a number" );

let addr = SocketAddr:: from (([ 127 , 0 , 0 , 1 ], port));
tracing::info!( "Listening on {addr}" );

let listener = TcpListener:: bind (&addr). await . unwrap ();
axum:: serve (listener, app). await . unwrap ();
}
```

## Quick test (manual)

Start the DB and run the server:

```bash
# start postgres (docker example) or make sure it is already started
docker run --name rust-postgres -e POSTGRES_PASSWORD=secret -p 5432 :5432 -d postgres:16

# set .env or export DATABASE_URL and PORT if you haven't
sqlx migrate run # applies migrations

cargo run
```

Create a user:

```bash
curl -X POST http://127.0.0.1:4000/users \
-H "Content-Type: application/json" \
-d '{"name":"Alice","email":"alice@example.com"}'
```

List users:

```bash
curl http://127.0.0.1:4000/users
```

## Wrap-up

- ✅ Project is refactored into modular files ready for scaling.
- ✅ SQLx + Postgres integration with migrations is in place.
- ✅ Endpoints: `POST /users` and `GET /users` work with the DB.


### Links

## [← Previous](/@ed.wacc1995/module-6-project-rust-rest-api-013c949a768e)

## [Next →](/@ed.wacc1995/module-6-2-full-crud-with-axum-sqlx-1b42a07bf02d)
