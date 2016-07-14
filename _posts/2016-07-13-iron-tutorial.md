---
layout: post
categories: обучение
title: "Введение в Iron"
author: Галимов Арсен aka "Loo Maclin"
excerpt: >
 Iron - это высокоуровневый веб-фреймворк, написанный на языке программирования
 Rust и построенный на базе другой небезызвестной библиотеки hyper. Iron разработан
 таким образом, чтобы пользоваться всеми преимуществами, которые нам предоставляет Rust.
 Iron старается избегать блокирующих операций в своём ядре.
---

##Немного об Iron

> Iron - это высокоуровневый веб-фреймворк, написанный на языке программирования
Rust и построенный на базе другой небезызвестной библиотеки hyper. Iron разработан
таким образом, чтобы пользоваться всеми преимуществами, которые нам предоставляет Rust.
Iron старается избегать блокирующих операций в своём ядре.

##Философия
Iron построен на принципе расширяемости настолько, насколько это возможно.
Он вводит понятия для расширения собственного функционала:
- "промежуточные" типажи - используются для реализации сквозного функционала в обработке запросов;
- модификаторы - используются для изменения запросов и ответов наиболее эргономичным
способом.

С базовой частью модификаторов и промежуточных типажей вы познакомитесь в ходе статьи.

##Создание проекта

Для начала создадим проект с помощью Cargo, используя команду:
```
cargo new rust-iron-tutorial --bin
```

Далее добавим в раздел `[dependencies]` файла `Cargo.toml` зависимость `iron = "0.4.0"`.

##Пишем первую программу с использованием Iron
Напишем первую простенькую программу на Rust с использованием Iron,
которая на любые запросы по порту 3000 будет отвечать текстом "Hello rustycrate!".

```Rust
extern crate iron;
use iron::prelude::*;
use iron::status;
fn main() {
   Iron::new(|_: &mut Request| {
       Ok(Response::with((status::Ok, "Hello rustycrate!\n")))
   }).http("localhost:3000").unwrap();
}
```

Запустите код при помощи команды `cargo run` и после того, как компиляция
завершится и программа запустится, протестируйте сервис, например, при помощи curl:

```
[loomaclin@loomaclin ~]$ curl localhost:3000
Hello World!
```

Давайте разберём программу, чтобы понимать, что тут происходит.
В первой строке программы импортируется пакет `iron`.
Во второй строке был подключен модуль-прелюдия, содержащий набор наиболее важных типажей, таких как `Request`,
`Response`, `IronRequest`, `IronResult`, `IronError` и `Iron`.
В третьей строке подключается модуль `status`, содержащий списки кодов для ответов на запросы.
`Iron::new` создаёт новый инстанс Iron'а, который, в свою очередь, является базовым объектом вашего сервера. Он
принимает параметром объект, реализующий типаж `Handler`. В нашем случае мы передаём замыкание, аргументом которого
является изменяемая ссылка на переданный запрос.

##Указываем mime-type в заголовке ответа

Чаще всего при построении веб-сервисов (soap, rest)
требуется отсылать ответы с указанием типа контента, который они содержат.
Для этого в Iron предусмотрены специальные средства.

Выполним следующее.

Подключаем соответствующую структуру:
```Rust
use iron::mime::Mime;
```
Связываем имя `content_type`, которое будет хранить распарсенное при помощи подключенного типажа `Mime` значение типа:
```Rust
let content_type = "application/json".parse::<Mime>().unwrap();
```
Модифицируем строку ответа на запрос следующим образом:
```Rust
Ok(Response::with((content_type, status::Ok, "{}")))
```
Запускаем программу и проверяем работоспособность:

```
[loomaclin@loomaclin ~]$ curl -v localhost:3000
* Rebuilt URL to: localhost:3000/
*   Trying ::1...
* Connected to localhost (::1) port 3000 (#0)
> GET / HTTP/1.1
> Host: localhost:3000
> User-Agent: curl/7.49.1
> Accept: */*
>
< HTTP/1.1 200 OK
< Content-Type: application/json
< Date: Tue, 12 Jul 2016 19:53:21 GMT
< Content-Length: 2
<
* Connection #0 to host localhost left intact
{}
```

##Управление статус-кодами ответов

В перечислении `StatusCode`, расположенном в модуле `status`, располагаются всевозможные статус-коды.
Давайте воспользуемся этим и вернём "клиенту" ошибку 404 -
`NotFound`, изменив строку с формированием ответа на запрос:

```Rust
Ok(Response::with((content_type, status::NotFound)))
```
Проверка:

```
[loomaclin@loomaclin ~]$ curl -v localhost:3000
* Rebuilt URL to: localhost:3000/
*   Trying ::1...
* Connected to localhost (::1) port 3000 (#0)
> GET / HTTP/1.1
> Host: localhost:3000
> User-Agent: curl/7.49.1
> Accept: */*
>
< HTTP/1.1 404 Not Found
< Content-Length: 2
< Content-Type: application/json
< Date: Tue, 12 Jul 2016 20:55:40 GMT
<
* Connection #0 to host localhost left intact
```

Примечание: по сути, весь модуль `status` является обёрткой для соответствующих
перечислений в библиотеке `hyper`, на которой базируется `iron`.

##Перенаправление запросов

Для редиректа в `iron` используется структура `Redirect` из модуля `modifiers` (не путать с `modifier`).
Она состоит из url цели, куда необходимо будет произвести перенаправление.
Попробуем её применить, проделав следующие изменения:

Подключаем структуру `Redirect`:
```Rust
use iron::modifiers::Redirect;
```

К подключению модуля `status` добавляем подключение модуля `Url`:
```Rust
use iron::{Url, status};
```

Связываем имя `url` , которое будет хранить распарсенное значение адреса редиректа:
```Rust
let url = Url::parse("https://rustycrate.ru/").unwrap();
```

Меняем блок инициализации Iron следующим образом:
```Rust
   Iron::new(move |_: &mut Request | {
       Ok(Response::with((status::Found, Redirect(url.clone()))))
   }).http("localhost:3000").unwrap();
```
Проверяем результат:

```
[loomaclin@loomaclin ~]$ curl -v localhost:3000
* Rebuilt URL to: localhost:3000/
*   Trying ::1...
* Connected to localhost (::1) port 3000 (#0)
> GET / HTTP/1.1
> Host: localhost:3000
> User-Agent: curl/7.49.1
> Accept: */*
>
< HTTP/1.1 302 Found
< Location: https://rustycrate.ru/
< Date: Tue, 12 Jul 2016 21:39:24 GMT
< Content-Length: 0
<
* Connection #0 to host localhost left intact
```

Также вы можете воспользоваться ещё одной структурой `RedirectRaw`
из модуля `modifiers`, для конструирования которой требуется лишь строка.

##Работа с типом http-запроса

У структуры `Request` есть поле `method`, позволяющее определять
тип пришедшего http-запроса.
Напишем сервис, который будет сохранять в файл данные, переданные в теле запроса с типом `Put`,
считывать данные из файла и передавать их в ответе на запрос с типом `Get`.

Аннотируем импортируемый контейнер `iron` с помощью атрибута `macro_use`,
чтобы в дальнейшем использовать макросы `iexpect` и `itry` для обработки ошибочных
ситуаций:

```Rust
#[macro_use]
extern crate iron;
```

Подключаем модули для работы с файловой системой и вводом/выводом
из стандартной библиотеки:

```Rust
use std::io;
use std::fs;
```
Подключаем модуль `method`, содержащий список типов http-запросов:
```Rust
use iron::method;
```
Меняем блок инициализации `Iron` таким образом, чтобы связать полученный запрос
с именем `req`:
```Rust
Iron::new(|req: &mut Request| {
   ...
   ...
   ...
}.http("localhost:3000").unwrap();
```
Добавляем в обработку запроса сопоставление с образцом поля `method` для
двух типов запросов `Get` и `Put`, а для остальных будем использовать
ответ в виде статус-кода `BadRequest`:
```Rust
       Ok(match req.method {
           method::Get => {
               let f = iexpect!(fs::File::open("foo.txt").ok(), (status::Ok, ""));
               Response::with((status::Ok, f))
           },
           method::Put => {
               let mut f = itry!(fs::File::create("foo.txt"));
               itry!(io::copy(&mut req.body, &mut f));
               Response::with(status::Created)
           },
           _ => Response::with(status::BadRequest)
       }
```

В `Iron` макрос `iexcept` используется для разворачивания переданного в него
объекта типа `Option` и в случае, если `Option` содержит `None` макрос,
возвращает `Ok(Response::new())` с модификатором по умолчанию `status::BadRequest`.
Макрос `itry` используется для оборачивания ошибки в `IronError`.

Пробуем запустить и проверить работоспособность.

PUT:
```
[loomaclin@loomaclin ~]$ curl -X PUT -d my_file_content localhost:3000
[loomaclin@loomaclin ~]$ cat ~/IdeaProjects/cycle/foo.txt
my_file_content
```

GET:
```
[loomaclin@loomaclin ~]$ curl localhost:3000
my_file_content
```

POST:
```
[loomaclin@loomaclin ~]$ curl -X POST -v localhost:3000
* Rebuilt URL to: localhost:3000/
*   Trying ::1...
* Connected to localhost (::1) port 3000 (#0)
> POST / HTTP/1.1
> Host: localhost:3000
> User-Agent: curl/7.49.1
> Accept: */*
>
< HTTP/1.1 400 Bad Request
< Content-Length: 0
< Date: Tue, 12 Jul 2016 22:29:58 GMT
<
* Connection #0 to host localhost left intact
```

##Реализация сквозного функционала при помощи пре- и пост-процессинга

В `iron` также присутствуют типажи `BeforeMiddleware`,`AfterMiddleware`
и `AroundMiddleware` для сквозного функционала,
позволяющие реализовывать логику по обработке запроса до того, как
она началась в основном обработчике, и после того, как она там завершилась.

Напишем пример использования ~~AOP'о подобных~~ указанных типажей:

```Rust
extern crate iron;

use iron::prelude::*;
use iron::{BeforeMiddleware, AfterMiddleware, AroundMiddleware, Handler};

struct SampleStruct;
struct SampleStructAroundHandler<H:Handler> { logger: SampleStruct, handler: H}

impl BeforeMiddleware for SampleStruct {
   fn before(&self, req: &mut Request) -> IronResult<()> {
       println!("До обработки запроса.");
       Ok(())
   }
}

impl AfterMiddleware for SampleStruct {
   fn after(&self, req: &mut Request, res: Response) -> IronResult<Response> {
       println!("После обработки запроса.");
       Ok(res)
   }
}

impl<H: Handler> Handler for SampleStructAroundHandler<H> {
   fn handle(&self, req: &mut Request) -> IronResult<Response> {
       println!("А я ещё один обработчик запроса.");
       let res = self.handler.handle(req);
       res
   }
}

impl AroundMiddleware for SampleStruct {
   fn around(self, handler: Box<Handler>) -> Box<Handler> {
       Box::new(SampleStructAroundHandler {
           logger: self,
           handler: handler
       }) as Box<Handler>
   }
}

fn sample_of_middlewares(_:&mut Request) -> IronResult<Response> {
   println!("В основном обработчике запроса.");
   Ok(Response::with((iron::status::Ok, "Привет, я ответ на запрос!")))
}

fn main() {
   let mut chain = Chain::new(sample_of_middlewares);
   chain.link_before(SampleStruct);
   chain.link_after(SampleStruct);
   chain.link_around(SampleStruct);
   Iron::new(chain).http("localhost:3000").unwrap();
}
```

В этом примере вводится структура `SampleStruct,` для которой
реализуются типажи `BeforeMiddleware` с функцией `before` и `AfterMiddleware`
с функцией `after`. С их помощью может быть реализована вся сквозная логика.
Типаж `AroundMiddleware` используется совместно с типажом `Handler` для
добавления дополнительного обработчика. Добавление всех реализованных
обработчиков в жизненный цикл обработки запроса производится с помощью
специального типажа `Chain`, позволяющего формировать цепь вызовов пре-
и пост-обработчиков.

Протестируем программу.
В консоли:
```
[loomaclin@loomaclin ~]$ curl localhost:3000
Привет, я ответ на запрос!
```
В выводе программы:
```
   Running `target/debug/cycle`
До обработки запроса.
А я ещё один обработчик запроса.
В основном обработчике запроса.
После обработки запроса.
```

##Роутинг

Какое серверное API может обойтись без роутинга? Добавим его =)
Модифицируем наш базовый пример из начала статьи следующим образом.

Подключаем коллекцию из стандартной библиотеки:
```Rust
use std::collections:HashMap;
```
Объявим структуру для хранения коллекции вида "путь - обработчик" и опишем
для этой структуры конструктор, который будет производить инициализацию этой
коллекции, и функцию для добавления в коллекцию новых роутов с их обработчиками:

```Rust
struct Router {

   routes: HashMap<String, Box<Handler>>

}

impl Router {

   fn new() -> Self {

       Router {
           routes: HashMap::new()
       }
   }

   fn add_route<H>(&mut self, path: String, handler: H) where H: Handler {
       self.routes.insert(path, Box::new(handler));
   }
}
```

Для использования нашей структуры в связке с `Iron` необходимо
реализовать для неё типаж `Handler` с функцией `handle`:

```Rust
impl Handler for Router {
fn handle(&self, req: &mut Request) -> IronResult<Response> {
match self.routes.get(&req.url.path().join("/")) {
Some(handler) => handler.handle(req),
None => Ok(Response::with(status::NotFound))
       }
   }
}
```
В функции `handle` мы по переданному в запросе пути находим соответствующий обработчик в
коллекции и вызываем обработчик этого пути с передачей в него запроса. В случае
если переданный в запросе путь не "зарегистрирован" в коллекции - возвращается
ответ с кодом ошибки `NotFound`.

Последнее, что осталось реализовать, - это инициализация нашего роутера и
регистрация в нём необходимых нам путей с их обработчиками:
```Rust
fn main() {
   let mut router = Router::new();
   router.add_route("hello_rustycrate".to_string(), |_: &mut Request| {
   Ok(Response::with((status::Ok, "Hello Loo Maclin!\n")))
   });
   router.add_route("hello_rustycrate/again".to_string(), |_: &mut Request| {
   Ok(Response::with((status::Ok, "Ты повторяешься!\n")))
   });
   router.add_route("error".to_string(), |_: &mut Request| {
   Ok(Response::with(status::BadRequest))
});
...
```
Добавление новых путей происходит путём вызова реалиованной выше функции.
Инициализируем инстанс `Iron` с использованием нашего роутера:
```Rust
Iron::new(router).http("localhost:3000").unwrap();
```
Тестируем:

```
[loomaclin@loomaclin ~]$ curl localhost:3000/hello_rustycrate
Hello Loo Maclin!
[loomaclin@loomaclin ~]$ curl localhost:3000/hello_rustycrate/again
Ты повторяешься!
[loomaclin@loomaclin ~]$ curl -v localhost:3000/error
*   Trying ::1...
* Connected to localhost (::1) port 3000 (#0)
> GET /error HTTP/1.1
> Host: localhost:3000
> User-Agent: curl/7.49.1
> Accept: */*
>
< HTTP/1.1 400 Bad Request
< Date: Wed, 13 Jul 2016 21:29:20 GMT
< Content-Length: 0
<
* Connection #0 to host localhost left intact
```

##Заключение

На этом статья подходит к концу.
Помимо рассмотренного функционала, Iron выносит большую часть типичной для
веб-фреймворка функциональности по базовым расширениям:

- [Роутинг](https://github.com/iron/router)
- [Монтирование](https://github.com/iron/mount)
- [Работа со статичными файлами](https://github.com/iron/staticfile)
- [Логирование](https://github.com/iron/logger)
- [Парсинг JSON в структуры](https://github.com/iron/body-parser)
- [Работа с закодированным URL](https://github.com/iron/urlencoded)
- [Куки](https://github.com/iron/cookie)
- [Механизм сессий](https://github.com/iron/session)

Статья предназначена для базового ознакомления с Iron, и хочется надеяться, что
она справляется с этой целью.

Спасибо за внимание!