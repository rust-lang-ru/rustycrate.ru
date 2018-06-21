---
categories: обучение
title: "Пишем простой веб сервис на языке программирования Rust"
author: Daniel Welch
original: https://danielwelch.github.io/rust-web-service.html
translator: Александр Андреев
---

Я новичок в языке Rust, но это быстро становится моим любимым языком программирования.
Хотя написание небольших проектов в Rust обычно менее эргономично
и занимает больше времени (по крайней мере, со мной за рулем),
это бросает вызов тому, как я думаю о дизайне программы.
Мои бои с компилятором становятся менее частыми, после того как я узнаю что-то новое.

Я работаю над [дополнением zigbee2mqtt Hass.io](https://github.com/danielwelch/hassio-zigbee2mqtt),
это расширение [Домашний помощник](https://developers.home-assistant.io/)
для платформы домашней автоматизации. Надстройка опирается на библиотеку
[`zigbee2mqtt`](https://github.com/Koenkk/zigbee2mqtt). `zigbee2mqtt` довольно новый проект,
быстро развивающийся и еще нет опубликованных релизов. Hass.io имеет дополнения,
которые распространяются как образы Docker, а дополнение `zigbee2mqtt` просто проверяет
последнюю ветвь `master` базовой библиотеки при построении образа Docker.
При таком подходе возникла проблема: когда новые коммиты были перенесены в `zigbee2mqtt`,
пользователи дополнения не могли обновиться до последней версии, пока образ дополнения не был собран
(что происходит автоматически в Travis CI только тогда, когда коммиты были
перенесены в репозиторий _add-on_). Мне нужен был способ запускать сборку
на Travis всякий раз, когда библиотека была изменена на Github.
Почему бы не реализовать это на языке Rust?

В этом посте я пройдусь по созданию простого веб-сервиса в Rust с помощью `actix-web`,
который принимает входящие сообщения `Github webhook` и запускает сборку `Travis CI` через `Travis API V3`.

<!--cut-->

### Перехват Github Webhook

Как только `webhooks` настроены, `Github API v3` передает
[PushEvent](https://developer.github.com/v3/activity/events/types/#pushevent)
на указанный URL с полезной нагрузкой в формате `JSON` с большим количеством
информации о коммите (описано в документации). Для целей этого примера
мы действительно заботимся только о поле `ref`, из которого мы можем получить информацию о ветке:

```rust
/// входящий PushEvent из Github Webhook.
#[derive(Deserialize)]
struct PushEvent {
    #[serde(rename = "ref")]
    reference: String,
}
```

`serve` помогает нам десериализовать полезную нагрузку в структуру `Push Event`
и [экстракторы](https://actix.rs/docs/extractors/) из `actix_web`
дают весьма легкий способ доступа к данным `JSON` в обработчике функции.
Функция-обработчик может принять некоторый тип `Json<T>` в качестве аргумента,
и тело запроса будет автоматически десериализовано в тип `T`,
пока он реализует типаж `Deserialize` из `serde`:

```rust
use  actix_web::Json;

fn index(push: Json<PushEvent>)  -> ...
```

Внутри обработчика тело запроса автоматически десериализуется в аргумент `push`, который имеет тип `PushEvent`.

### Проверка заголовков с помощью Middleware

`Github webhooks` может сопровождаться секретным значением для аутентификации.
Если секретное значение указано, то оно использовано для создания `HMAC-SHA1` тела запроса
и отправляться с запросом через заголовок `"X-Hub-Signature` в формате `sha1=<HMAC>`.
Мы можем реализовать `middleware` с `actix_web`, чтобы проверить этот заголовок для каждого запроса:

```rust
use actix_web::HttpRequest;
use actix_web::middleware::{Middleware, Started};
use actix_web::error::{ErrorUnauthorized, ParseError};
use actix_web::Result;

struct VerifySignature;

impl<S> Middleware<S> for VerifySignature {
    fn start(&self, req: &mut HttpRequest<S>) -> Result<Started> {
        use std::io::Read;

        let r = req.clone();
        let s = r.headers()
            .get("X-Hub-Signature")
            .ok_or(ErrorUnauthorized(ParseError::Header))?
            .to_str()
            .map_err(ErrorUnauthorized)?;
        // получаем "sha1=" из заголовка
        let (_, sig) = s.split_at(5);

        let secret = env::var("GITHUB_SECRET").unwrap();
        let mut body = String::new();
        req.read_to_string(&mut body)
            .map_err(ErrorInternalServerError)?;

        if is_valid_signature(&sig, &body, &secret) {
            Ok(Started::Done)
        } else {
            Err(ErrorUnauthorized(ParseError::Header))
        }
    }
}
```

Функция `is_valid_signature` определена как у [@aergonaut](https://github.com/aergonaut/railgun/blob/213c546da9b79786d38f18ee67bdd2ab73034232/src/railgun/request.rs#L87) (в этом [блоге](https://medium.com/@aergonaut/writing-a-github-webhook-with-rust-part-1-rocket-4426dd06d45d) более подробно).
Используя пакет `crytpo`, мы сравниваем подпись в заголовке `X-Hub-Signature`,
которую мы рассчитываем из тела запроса и нашего секретного значения.
Единственное существенное различие заключается в том, как строится шестнадцатеричная строка (не требует `unsafe` кода)
и как обрабатывается префикс `sha1=`.

_Спасибо [/u/vbrandl](https://www.reddit.com/user/vbrandl) на `Reddit`, который объяснил мне как это работает._

### Использование Travis API

[Travis V3 API](https://docs.travis-ci.com/user/triggering-builds/) предоставляет
конечную точку `/repo/{slug|id}/requests`, которая позволяет запускать новые сборки.
Исходя из документации, вот основной запрос, который нам нужно реализовать:

```bash
body='{
"request": {
"message": "Override the commit message: this is an api request",
"branch":"master"
}}'

curl -s -X POST \
   -H "Content-Type: application/json" \
   -H "Accept: application/json" \
   -H "Travis-API-Version: 3" \
   -H "Authorization: token xxxxxx" \
   -d "$body" \
   https://api.travis-ci.com/repo/danielwelch%2Fhassio-zigbee2mqtt/requests
```

В `hyper` есть хороший макрос, который позволяет нам определять пользовательские заголовки,
сохраняя при этом безопасность типов.

```rust
header! { (TravisAPIVersion, "Travis-API-Version") => [u16] }
```

Теперь мы можем добавить наши заголовки и тело `JSON`
[`reqwest::RequestBuilder`](https://docs.rs/reqwest/0.8.5/reqwest/struct.RequestBuilder.html).

```rust
#[derive(Serialize)]
struct TravisRequest {
    message: String,
    branch: String,
}

fn travis_request(url: &str) -> Result<reqwest::Response> {
    let client = reqwest::Client::new();
    let res = client
        .post(url)
        .header(reqwest::header::ContentType::json())
        .header(TravisAPIVersion(3))
        .header(reqwest::header::Authorization(auth_str()))
        .json(&TravisRequest {
            message: "API Request triggered by zigbee2mqtt update".to_string(),
            branch: "master".to_string(),
        })
        .send()
        .map_err(ErrorInternalServerError)?;
    Ok(res)

fn auth_str() -> String {
    format!("token {}", std::env::var("TRAVIS_TOKEN").unwrap()).to_owned()
}
```

### Проектирование реализации типажа Responder

В `actix-web`, обработчик просто должен реализовать [Handler](https://actix.rs/actix-web/actix_web/dev/trait.Handler.html),
который уже реализован для любой функции, которая принимает `HttpRequest` и возвращает типаж [Responder](https://actix.rs/actix-web/actix_web/trait.Responder.html).
`Json<T>` реализует `FromRequest`, который преобразует `HttpRequest` в `Json<T>` за сценой.
Взяв первую часть нашего определения функции выше, мы можем теперь закончить ее, зная, что нам нужно вернуть.

```rust
fn index(push: Json<PushEvent>) -> impl Responder {} // очень причудливый и новый `impl Trait` в выходном значении функции
```

Все, что осталось сделать, это реализовать типаж `Responder` в соответствии с документацией.
Это будет сообщение в формате JSON, которое будет отправлено в ответ на успешный запрос.

```rust
use actix_web::{Responder, HttpRequest, HttpResponse, Error};

#[derive(Serialize)]
struct ServerMessage(String)

impl Responder for ServerMessage {
    type Item = HttpResponse;
    type Error = Error;

    fn respond_to<S>(self, _req: &HttpRequest<S>) -> Result<HttpResponse, Error> {
        let body = serde_json::to_string(&self)?;
        Ok(HttpResponse::Ok()
            .content_type("application/json")
            .body(body))
    }
}
```

Объединение всех элементов вместе:

```rust
use std::env;
use actix_web::{Json, Responder, HttpRequest, HttpResponse, Error};
use actix_web::error::ErrorInternalServerError;

fn index(push: Json<PushEvent>) -> impl Responder {
    let travis_url = env::var("TRAVIS_URL").unwrap();
    if push.reference.ends_with("master") {
        match travis_request("https://api.travis-ci.org/repo/19145006/requests") {
            Ok(_) => ServerMessage(format!(
                "PushEvent on branch master found, request sent to {}",
                travis_url).to_owned()),
            Err(e) => ErrorInternalServerError(e),
        }
    } else {
        ServerMessage("PushEvent is not for master branch".to_owned())
    }
}
```

Это не сработает. Компилятор жалуется на несоответствие типов в операторе match.
Документация `actix-web` предлагает использовать [`Either`](https://actix.rs/actix-web/actix_web/enum.Either.html),
чтобы вернуть два разных типа.

```rust
use actix_web::Either;

type ServerResponse = Either<ServerMessage, Error>;

fn index(push: Json<PushEvent>) -> impl Responder {
    let travis_url = env::var("TRAVIS_URL").unwrap();
    if push.reference.ends_with("master") {
        match travis_request("https://api.travis-ci.org/repo/19145006/requests") {
            Ok(_) => Either::A(
                ServerMessage(format!(
                    "PushEvent on branch master found, request sent to {}",
                    travis_url)
                .to_owned())
            ),
            Err(e) => Either::B(ErrorInternalServerError(e)),
        }
    } else {
        Either::A(ServerMessage("PushEvent is not for master branch".to_owned()))
    }
}
```

Это работает, но мне это не нравится. Это уродливо и кажется слишком сложным для такого простого случая.
Должен быть лучший способ, чем это, чтобы вернуть сериализованное сообщение или HTTP ошибку от ресурса `actix-web`.
И, прочитав больше документации, я обнаружил, что есть лучшие способы.
Я был заинтересован в том, чтобы использовать мою реализацию типажа `Responder` для `ServerMessage`
и сохранить большую часть логики обработчика ответов, привязанной к этой `struct`,
потому что это заставило меня чувствовать себя круто.
По сути, моя реализация типажа `Responder` в методе `respond_to` уже готов вернуть в `Result` либо `HttpResponse` или `Error`.
Почему мы не обрабатываем ошибку в структуре `SeverMessage` и ее реализации ответа?

```rust
#[derive(Serialize)]
struct ServerMessage {
    message: String,

    // нам не нужно сериализовать ошибку,
    // она будет передана в
    // составе структуры `ServerMessage` в `HTTPResponse`
    #[serde(skip_serializing)]
    e: Option<Error>,
}


impl Responder for ServerMessage {
    type Item = HttpResponse;
    type Error = Error;

    fn respond_to<S>(self, _req: &HttpRequest<S>) -> Result<HttpResponse, Error> {
        if self.e.is_some() {
            return Err(self.e.unwrap());
        } else {
            let body = serde_json::to_string(&self)?;
            Ok(HttpResponse::Ok()
                .content_type("application/json")
                .body(body))
        }
    }
}
```

Таким образом, ошибка может быть захвачена в `struct` и обработана во время ответа.
Ошибка определяется в какой-то другой момент цикла запрос-ответ - это не имеет значения,
где и что ошибка, пока это `actix-web::Error`. Добавление некоторых методов для удобства,
чтобы сделать вещи немного чище...

```rust
impl ServerMessage {
    fn success<T: ToString>(s: T) -> ServerMessage {
        ServerMessage {
            message: s.to_string(),
            e: None,
        }
    }

    fn error(e: Error) -> ServerMessage {
        ServerMessage {
            message: "".to_owned(),
            e: Some(e),
        }
    }
}
```

И наш конечный вариант выглядит намного лучше:

```rust
fn index(push: Json<PushEvent>) -> impl Responder {
    let travis_url = env::var("TRAVIS_URL").unwrap();
    if push.reference.ends_with("master") {
        match travis_request("https://api.travis-ci.org/repo/19145006/requests") {
            Ok(_) => ServerMessage::success(format!(
                "PushEvent on branch master found, request sent to {}",
                travis_url
            )),
            Err(e) => ServerMessage::error(e),
        }
    } else {
        ServerMessage::success("PushEvent is not for master branch")
    }
}
```

Все, что осталось сделать, это запустить сервер в `main.rs`.

```rust
/// функция utility из примера проекта `heroku buildpack`
fn get_server_port() -> u16 {
    env::var("PORT")
        .ok()
        .and_then(|p| p.parse().ok())
        .unwrap_or(8080)
}

fn main() {
    use std::net::{SocketAddr, ToSocketAddrs};
    let sys = actix::System::new("updater");
    let addr = SocketAddr::from(([0, 0, 0, 0], get_server_port()));

    server::new(|| {
        App::new()
            .middleware(HeaderCheck)
            .resource("/", |r| r.method(http::Method::POST).with(index))
    }).bind(addr)
        .unwrap()
        .start();

    let _ = sys.run();
}
```

### Заключение

Оказывается, проще было просто предоставить автору `zigbee2mqtt` доступ на запись
и заставить его запустить сборку через скрипт `after_success` в этом репозитории.
Тем не менее, это было забавное упражнение в основах нового веб-фреймворка Rust,
и некоторые новые концепции, которые он вводит.
Исходные коды проекта данной статьи смотрите [здесь](https://github.com/danielwelch/zigbee2mqtt-hassio-updater)