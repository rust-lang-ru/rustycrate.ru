---
layout: post
categories: обучение
title: "Введение в Iron"
author: Галимов Арсен
excerpt: >
  Это вводная статья по веб-фреймворку Iron.
---

#####Создание проекта

Для начала создадим проект при помощи Cargo используя команду:
``cargo new rust-iron-tutorial --bin``

Далее добавим в раздел `[dependencies]` файла Cargo.toml зависимость `iron = "0.4.0"`.

#####Пишем первую программу с использованием Iron
Напишем первую простенькую программу на Rust с использованием Iron,
которая будет на любые запросы по порту 3000 отвечать текстом "Hello rustycrate!".

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

Запустите код при помощи команды `cargo run` и после того как компиляция
завершится и программа запустится протестируйте сервис например при помощи curl:

```
[loomaclin@loomaclin ~]$ curl localhost:3000
Hello World!
```

Давайте разберём программу, чтобы понимать, что тут происходит.
В первой строке программы объявлен внешний крэйт `iron`.
Во второй строке был подключен модуль.
В Iron, как и в самом Rust есть модуль-прелюдия содержащий набор наиболее важных трэйтов, таких как `Request`,
`Response`, `IronRequest`, `IronResult`, `IronError` и `Iron`.
В третьей строке подключается модуль `status` содержащий списки кодов для ответов на запросы.
`Iron::new` создаёт новый инстанс Iron'а, который в свою очередь является базовым объектом вашего сервера. Он
принимает параметром объект реализующий типаж `Handler`, в нашем случае мы передаём замыкание аргументом которого
является изменяемая ссылка на переданный запрос.

#####Указываем mime-type в заголовке ответа

Чаще всего при построении веб-сервисов (soap, rest)
требуется отсылать ответы с указанием типа контента, который они содержат.
Для этого в Iron предусмотрены специальные средства.

Выполним следующее:
1. Подключим соответствующую структуру:
```Rust
use iron::mime::Mime;
```
2. Связываем имя `content_type`, которое будет хранить распарсенное при помощи подключенного типажа `Mime` значение типа:
```Rust
let content_type = "application/json".parse::<Mime>().unwrap();
```
3. Модифицируем строку ответа на запрос следующим образом:
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

#####Управление статус-кодами ответов

В перечислении `StatusCode` расположенном в модуле `status` распологаются всевозможные статус-коды.
Давайте воспользуемся этим и вернём "клиенту" ошибку 404 -
NotFound изменив строку с формированием ответа на запрос:

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

Примечание: по-сути весь модуль `status` является обёрткой для соответствующих
перечислений в библиотеке `hyper`, на которй базируется `iron`.

#####Перенаправление запросов

Для редиректа в `iron` используется структура `Redirect` из модуля `modifiers` (не путать с `modifier`).
Она состоит из url цели, куда необходимо будет произвести перенаправление.
Попробуем её применить проделав следующие изменения:

1. Подключаем структуру `Redirect`:
```Rust
use iron::modifiers::Redirect;
```

2. К подключению модуля `status` добавляем подключение структуры `Url`:
```Rust
use iron::{Url, status};
```

3. Связываем имя `url` , которое будет хранить распарсенное значение адреса редиректа:
```Rust
let url = Url::parse("https://rustycrate.ru/").unwrap();
```

4. Меняем блок инициализации Iron следующим образом:
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

Так же вы можете воспользоваться ещё одной структурой `RedirectRaw`
из модуля `modifiers`, для конструирования которой требуется лишь строка.

#####Работа с типом http-запроса

У структуры `Request` есть поле `method` позволяющее определять,
какой тип http-запроса пришёл.
Напишем сервис, который будет сохранять данные в файл, которые были переданы в
теле запроса в случае если тип запроса был `Put` и считывать данные из-файла и
передавать их в ответе на запрос, в случа если тип запроса был `Get`:

```Rust
#[macro_use]
extern crate iron;

use std::io;
use std::fs;

use iron::prelude::*;
use iron::status;
use iron::method;

fn main() {
    Iron::new(|req: &mut Request| {
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
        })
    }).http("localhost:3000").unwrap();
}
```
В этой программе добавился импорт перечисления `method`
содержащее все типы http-запросов, а так же обработка самого запроса
с использованием сопоставления с образцом его поля и элементов из вышеуказанного
перечисления. Попробуем запустить и проверить работоспособность этой программы.

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

Всё как и ожидалось. Но, если вы были внимательны - то могли заметить,
что `Iron` вводит собственные макросы для обработки ошибок: `itry` и `iexpect`.