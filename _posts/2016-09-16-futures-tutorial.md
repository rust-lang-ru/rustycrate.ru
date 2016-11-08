---
layout: post
categories: обучение
title: "futures-rs: асинхронщина на Rust"
author: Alex Crichton (перевёл Арсен Галимов)
---

# Начинаем работу с `futures`

Этот документ поможет вам изучить контейнер для языка программирования Rust - `futures`,
который обеспечивает реализацию futures и потоков с нулевой стоимостью.
Futures доступны во многих других языках программирования, таких как `C++`, `Java`, и `Scala`, и контейнер `futures`
черпает вдохновение из библиотек этих языков. Однако он отличается эргономичностью, а также
придерживается философии абстракций с нулевой стоимостью, присущей Rust, а именно: для создания и композиции futures не
требуется выделений памяти, а для `Task`, управляющего ими, нужна только одна аллокация. Futures
должны стать основой асинхронного компонуемого высокопроизводительного ввода/вывода в Rust, и
ранние замеры производительности показывают, что простой HTTP сервер, построенный на futures, действительно быстр.

Эта документация разделена на несколько разделов:

- "Здравствуй, мир!";
- типаж future;
- типаж `Stream`;
- конкретные futures и поток(`Stream`);
- возвращение futures;
- `Task` и future;
- локальные данные задачи.

<!--cut-->

# Здравствуй, мир!

Контейнер `futures` требует Rust версии 1.10.0 или выше, который может быть легко установлен с помощью `rustup`.
Контейнер проверен и точно работает на Windows, macOS и Linux, но PR'ы для других платформ всегда приветствуются.
Вы можете добавить `futures` в `Cargo.toml` своего проекта следующим образом:

```
[dependencies]
futures = { git = "https://github.com/alexcrichton/futures-rs" }
tokio-core = { git = "https://github.com/tokio-rs/tokio-core" }
tokio-tls = { git = "https://github.com/tokio-rs/tokio-tls" }
```

> Примечание: эта библиотека в активной разработке и требует получения исходников с git напрямую, но позже контейнер
будет опубликован на crates.io.

Здесь мы добавляем в зависимости три контейнера:

- [futures](https://github.com/alexcrichton/futures-rs) - определение и ядро реализации `Future` и `Stream`;
- [tokio-core](https://github.com/tokio-rs/tokio-core) - привязка к контейнеру `mio`, предоставляющая конкретные
реализации `Future` и `Stream` для TCP и UDP;
- [tokio-tls](https://github.com/tokio-rs/tokio-tls) - реализация SSL/TLS на основе futures.

Контейнер [futures](https://github.com/alexcrichton/futures-rs) является низкоуровневой реализацией futures,
которая не несёт в себе какой-либо среды выполнения или слоя ввода/вывода. Для примеров ниже воспользуемся
конкретными реализациями, доступными в [tokio-core](https://github.com/tokio-rs/tokio-core),
чтобы показать, как futures и потоки
могут быть использованы для выполнения сложных операций ввода/вывода с нулевыми накладными расходами.

Теперь, когда у нас есть всё необходимое, напишем первую программу. В качестве hello-world примера скачаем домашнюю
страницу Rust:

```rust
extern crate futures;
extern crate tokio_core;
extern crate tokio_tls;

use std::net::ToSocketAddrs;

use futures::Future;
use tokio_core::reactor::Core;
use tokio_core::net::TcpStream;
use tokio_tls::ClientContext;

fn main() {
    let mut core = Core::new().unwrap();
    let addr = "www.rust-lang.org:443".to_socket_addrs().unwrap().next().unwrap();

    let socket = TcpStream::connect(&addr, &core.handle());

    let tls_handshake = socket.and_then(|socket| {
        let cx = ClientContext::new().unwrap();
        cx.handshake("www.rust-lang.org", socket)
    });
    let request = tls_handshake.and_then(|socket| {
        tokio_core::io::write_all(socket, "\
            GET / HTTP/1.0\r\n\
            Host: www.rust-lang.org\r\n\
            \r\n\
        ".as_bytes())
    });
    let response = request.and_then(|(socket, _)| {
        tokio_core::io::read_to_end(socket, Vec::new())
    });

    let (_, data) = core.run(response).unwrap();
    println!("{}", String::from_utf8_lossy(&data));
}
```

Если создать файл с таким содержанием по пути `src/main.rs` и запустить команду `cargo run`, то отобразится HTML
главной страницы Rust.

> Примечание: rustc 1.10 компилирует этот пример медленно. С 1.11 компиляция происходит быстрее.

Этот код слишком большой, чтобы разобраться в нём сходу, так что пройдёмся построчно.
Взглянем на функцию `main()`:

```rust
let mut core = Core::new().unwrap();
let addr = "www.rust-lang.org:443".to_socket_addrs().unwrap().next().unwrap();
```

[Здесь создается цикл событий](https://tokio-rs.github.io/tokio-core/tokio_core/reactor/struct.Core.html#method.new), в
котором будет выполняться весь ввод/вывод. После преобразуем имя хоста
["www.rust-lang.org"](https://www.rust-lang.org) с использованием метода `to_socket_addrs` из стандартной библиотеки.

Далее:

```rust
let socket = TcpStream::connect(&addr, &core.handle());
```

[Получаем хэндл](https://tokio-rs.github.io/tokio-core/tokio_core/reactor/struct.Core.html#method.handle) цикла событий
и соединяемся с хостом при помощи
[TcpStream::connect](https://tokio-rs.github.io/tokio-core/tokio_core/net/struct.TcpStream.html#method.connect).
Примечательно, что
[TcpStream::connect](https://tokio-rs.github.io/tokio-core/tokio_core/net/struct.TcpStream.html#method.connect) возвращает
future. В действительности, сокет не подключен, но подключение произойдёт позже.

После того, как сокет станет доступным, нам необходимо выполнить три шага для загрузки домашней страницы rust-lang.org:

1. Выполнить TLS хэндшэйк. Работать с этой домашней страницей можно только по HTTPS, поэтому мы должны
подключиться к порту 443 и следовать протоколу TLS.

2. Отправить HTTP `GET` запрос. В рамках этого руководства мы напишем запрос вручную, тем не менее,
в боевых программах следует использовать HTTP клиент, построенный на `futures`.

3. В заключение, скачать ответ посредством чтения всех данных из сокета.

Рассмотрим каждый из этих шагов подробно.
Первый шаг:

```rust
let tls_handshake = socket.and_then(|socket| {
    let cx = ClientContext::new().unwrap();
    cx.handshake("www.rust-lang.org", socket)
});
```

Здесь используется метод [and_then](https://docs.rs/futures/0.1.3/futures/trait.Future.html#method.and_then)
типажа future, вызывая его у результата выполнения метода
[TcpStream::connect](https://tokio-rs.github.io/tokio-core/tokio_core/net/struct.TcpStream.html#method.connect). Метод
[and_then](https://docs.rs/futures/0.1.3/futures/trait.Future.html#method.and_then) принимает
замыкание, которое получает значение предыдущего future. В этом случае `socket` будет иметь тип
[TcpStream](https://tokio-rs.github.io/tokio-core/tokio_core/net/struct.TcpStream.html). Стоит отметить, что замыкание,
переданное в [and_then](https://docs.rs/futures/0.1.3/futures/trait.Future.html#method.and_then), не будет
выполнено в случае если
[TcpStream::connect](https://tokio-rs.github.io/tokio-core/tokio_core/net/struct.TcpStream.html#method.connect) вернёт
ошибку.

Как только получен `socket`, мы создаём клиентский TLS контекст с помощью
[ClientContext::new](https://tokio-rs.github.io/tokio-tls/tokio_tls/struct.ClientContext.html#method.new). Этот тип
из контейнера `tokio-tls` представляет клиентскую часть TLS соединения.
Далее вызываем метод
[handshake](https://tokio-rs.github.io/tokio-tls/tokio_tls/struct.ClientContext.html#method.handshake),
чтобы выполнить TLS хэндшейк. Первый аргумент - доменное имя, к которому мы подключаемся, второй - объект
ввода/вывода (в данном случае объект `socket`).

Как и [TcpStream::connect](https://tokio-rs.github.io/tokio-core/tokio_core/net/struct.TcpStream.html#method.connect)
раннее, метод [handshake](https://tokio-rs.github.io/tokio-tls/tokio_tls/struct.ClientContext.html#method.handshake)
возвращает future. TLS хэндшэйк может занять некоторое время, потому что клиенту и серверу необходимо
выполнить некоторый ввод/вывод, подтверждение сертификатов и т.д. После выполнения future вернёт
[TlsStream](https://tokio-rs.github.io/tokio-tls/tokio_tls/struct.TlsStream.html), похожий на расмотренный выше
[TcpStream](https://tokio-rs.github.io/tokio-core/tokio_core/net/struct.TcpStream.html).

Комбинатор [and_then](https://docs.rs/futures/0.1.3/futures/trait.Future.html#method.and_then) выполняет
много скрытой работы, обеспечивая выполнение futures в правильном порядке и отслеживая их на лету.
При этом значение, возвращаемое
[and_then](https://docs.rs/futures/0.1.3/futures/trait.Future.html#method.and_then), реализует типаж
[Future](https://docs.rs/futures/0.1.3/futures/trait.Future.html), поэтому мы можем составлять цепочки
вычислений.

Далее отправляем HTTP запрос:

```rust
let request = tls_handshake.and_then(|socket| {
    tokio_core::io::write_all(socket, "\
        GET / HTTP/1.0\r\n\
        Host: www.rust-lang.org\r\n\
        \r\n\
    ".as_bytes())
});
```

Здесь мы получили future из предыдущего шага (`tls_handshake`) и использовали
[and_then](https://docs.rs/futures/0.1.3/futures/trait.Future.html#method.and_then) снова, чтобы продолжить
вычисление. Комбинатор [write_all](https://tokio-rs.github.io/tokio-core/tokio_core/io/fn.write_all.html) полностью
записывает HTTP запрос, производя многократные записи по необходимости.

Future, возвращаемый методом [write_all](https://tokio-rs.github.io/tokio-core/tokio_core/io/fn.write_all.html), будет
выполнен, как только все данные будут записаны в сокет. Примечательно, что
[TlsStream](https://tokio-rs.github.io/tokio-tls/tokio_tls/struct.TlsStream.html) скрыто шифрует все данные, которые
мы записывали, перед тем как отправить в сокет.

Третья и последняя часть запроса выглядит так:

```rust
let response = request.and_then(|(socket, _)| {
    tokio_core::io::read_to_end(socket, Vec::new())
});
```

Предыдущий future `request` снова связан, на этот раз с результатом выполнения комбинатора
[read_to_end](https://tokio-rs.github.io/tokio-core/tokio_core/io/fn.read_to_end.html). Этот future будет читать все
данные из сокета и помещать их в предоставленный буфер и вернёт буфер, когда обрабатываемое соединение передаст EOF.

Как и ранее, чтение из сокета на самом деле скрыто расшифровывает данные, полученные от сервера, так что мы читаем
расшифрованную версию.

Если испонение прервётся на этом месте, вы удивитесь, так как ничего не произойдёт.
Это потому что всё, что мы сделали, основано на future вычислениях, и мы на самом деле
не запустили их. До этого момента мы не делали никакого ввода/вывода и не выполняли HTTP запросов и т.д.

Чтобы по-настоящему запустить futures и управлять ими до завершения, необходимо запустить цикл событий:

```rust
let (_, data) = core.run(response).unwrap();
println!("{}", String::from_utf8_lossy(&data));
```

Здесь future `response` помещается в цикл событий, [запрашивая у него
выполнение future](https://tokio-rs.github.io/tokio-core/tokio_core/reactor/struct.Core.html#method.run).
Цикл событий будет выполняться, пока не будет получен результат.

Примечательно, что вызов `core.run(..)` блокирует вызывающий поток, пока future не сможет быть возвращен. Это
означает, что `data` имеет тип `Vec<u8>`. Тогда мы можем напечатать это в stdout как обычно.

Фух! Мы рассмотрели futures,
[инициализирующие TCP соедениение](https://tokio-rs.github.io/tokio-core/tokio_core/net/struct.TcpStream.html#method.connect),
[создающие цепочки вычислений](https://docs.rs/futures/0.1.3/futures/trait.Future.html#method.and_then) и
[читающие данные из сокета](https://tokio-rs.github.io/tokio-core/tokio_core/io/fn.read_to_end.html). Но это только
пример возможностей futures, далее рассмотрим нюансы.

# Типаж Future

Типаж future является ядром контейнера `futures`. Этот типаж представляет асинхронные вычисления и их результат.
Взглянем на следующий код:

```rust
trait Future {
    type Item;
    type Error;

    fn poll(&mut self) -> Poll<Self::Item, Self::Error>;

    // ...
}
```

Я уверен, что определение содержит ряд пунктов, вызывающих вопросы:

- `Item` и `Error`;
- `poll`;
- комбинаторы future.

Разберём их детально.

## `Item` и `Error`

```rust
type Item;
type Error;
```

Первая особенность типажа future, как вы, вероятно, заметили, это то, что он содержит два ассоциированных типа.
Они представляют собой типы значений, которые future может получить. Каждый экземпляр `Future` можно обработать как
`Result<Self::Item, Self::Error>`.

Эти два типа будут применяться очень часто в условиях `where` при передаче futures и в сигнатурах типа, когда
futures будут возвращаться. Для примера, при возвращении future можно написать:

```rust
fn foo() -> Box<Future<Item = u32, Error = io::Error>> {
    // ...
}
```

Или, когда принимаем future:

```rust
fn foo<F>(future: F)
    where F: Future<Error = io::Error>,
          F::Item: Clone,
{
    // ...
}
```

## `poll`

```rust
fn poll(&mut self) -> Poll<Self::Item, Self::Error>;
```

Работа типажа [Future](https://docs.rs/futures/0.1.3/futures/trait.Future.html) построена на этом методе.
Метод [poll](https://docs.rs/futures/0.1.3/futures/trait.Future.html#tymethod.poll) - это единственная точка
входа для извлечения вычисленного в future значения. Как пользователю future вам редко понадобится вызывать этот
метод напрямую. Скорее всего, вы будете взаимодействовать с futures через комбинаторы, которые создают
высокоуровневые абстракции вокруг futures. Однако знание того, как futures работают под капотом, будет полезным.

Подробнее рассмотрим метод [poll](https://docs.rs/futures/0.1.3/futures/trait.Future.html#tymethod.poll).
Обратим внимание на аргумент `&mut self`, который вызывает ряд ограничений и свойств:

- futures могут быть опрошены только одним потоком единовременно;
- во время выполнения метода `poll`, futures могут изменять своё состояние;
- после заврешения `poll` владение futures может быть передано другой сущности.

На самом деле тип [Poll](https://docs.rs/futures/0.1.3/futures/type.Poll.html) является псевдонимом:

```
type Poll<T, E> = Result<Async<T>, E>;
```

Так же взглянем, что из себя представляет перечисление
[Async](https://docs.rs/futures/0.1.3/futures/enum.Async.html):

```rust
pub enum Async<T> {
    Ready(T),
    NotReady,
}
```

Посредством этого перечисления futures могут взаимодействовать, когда значение future готово
к использованию. Если произошла ошибка, тогда будет сразу возвращено `Err`. В противном случае, перечисление
[Async](https://docs.rs/futures/0.1.3/futures/enum.Async.html) отображает, когда значение Future полностью
получено или ещё не готово.

Типаж [Future](https://docs.rs/futures/0.1.3/futures/trait.Future.html), как и `Iterator`, не определяет, что
происходит после вызова метода [poll](https://docs.rs/futures/0.1.3/futures/trait.Future.html#tymethod.poll),
если future уже обработан. Это означает, что тем, кто реализует типаж
[Future](https://docs.rs/futures/0.1.3/futures/trait.Future.html), не нужно поддерживать состояние,
чтобы проверить, успешно ли вернул результат метод
[poll](https://docs.rs/futures/0.1.3/futures/trait.Future.html#tymethod.poll).

Если вызов [poll](https://docs.rs/futures/0.1.3/futures/trait.Future.html#tymethod.poll) возвращает
`NotReady`, future всё ещё требуется знать, когда необходимо выполниться снова.
Для достижения этой цели future должен обеспечить следующий механизм: при получении `NotReady`
текущая задача должна иметь возможность получить уведомление, когда значение станет доступным.

Метод [park](https://docs.rs/futures/0.1.3/futures/task/fn.park.html) является основной точкой входа доставки
уведомлений. Эта функция возвращает [Task](https://docs.rs/futures/0.1.3/futures/task/struct.Task.html),
который реализует типажи `Send` и `'static`, и имеет основной метод -
[unpark](https://docs.rs/futures/0.1.3/futures/task/struct.Task.html#method.unpark). Вызов метода
[unpark](https://docs.rs/futures/0.1.3/futures/task/struct.Task.html#method.unpark) указывает, что future
может производить вычисления и возвращать значение.

Более детальную документацию можно найти
[здесь](https://docs.rs/futures/0.1.3/futures/trait.Future.html#tymethod.poll).

## Комбинаторы future

Теперь кажется, что метод [poll](https://docs.rs/futures/0.1.3/futures/trait.Future.html#tymethod.poll)
может внести немного боли в ваш рабочий процесс. Что если у вас есть future, который
должен вернуть `String`, а вы хотите конвертировать его в future, возвращающий `u32`? Для получения такого рода
композиций типаж future обеспечивает большое число *комбинаторов*.

Эти комбинаторы аналогичны комбинаторам из типажа [Iterator](https://doc.rust-lang.org/std/iter/trait.Iterator.html),
и все они принимают future и возвращают новый future. Для примера, мы могли бы написать:

```rust
fn parse<F>(future: F) -> Box<Future<Item=u32, Error=F::Error>>
    where F: Future<Item=String> + 'static,
{
    Box::new(future.map(|string| {
        string.parse::<u32>().unwrap()
    }))
}
```

Здесь для преобразования future, возвращающий тип `String`, во future, возвращающий `u32`, используется
[map](https://docs.rs/futures/0.1.3/futures/struct.Map.html). Упаковывание в
[Box](https://doc.rust-lang.org/std/boxed/struct.Box.html) не всегда необходимо и более подробно будет рассмотрено в
разделе [возвращений futures](https://github.com/alexcrichton/futures-rs/blob/master/TUTORIAL.md#returning-futures).

Комбинаторы позволяют выражать следующие понятия:

- изменение типа future ([map](https://docs.rs/futures/0.1.3/futures/struct.Map.html),
[map_err](https://docs.rs/futures/0.1.3/futures/trait.Future.html#method.map_err));
- запуск другого future, когда исходный будет выполнен (
[then](https://docs.rs/futures/0.1.3/futures/trait.Future.html#method.then),
[and_then](https://docs.rs/futures/0.1.3/futures/trait.Future.html#method.and_then),
[or_else](https://docs.rs/futures/0.1.3/futures/trait.Future.html#method.or_else));
- продолжение выполнения, когда хотя бы один из futures выполнился (
[select](https://docs.rs/futures/0.1.3/futures/trait.Future.html#method.select));
- ожидание выполнения двух future (
[join](https://docs.rs/futures/0.1.3/futures/trait.Future.html#method.join));
- определение поведения `poll` после вычислений (
[fuse](https://docs.rs/futures/0.1.3/futures/trait.Future.html#method.fuse)).

Использование комбинаторов похоже на использование типажа `Iterator` в Rust или `futures` в Scala.
Большинство манипуляций с futures заканчивается использованием этих комбинаторов. Все комбинаторы имеют нулевую
стоимость, что означает отсутствие выделений памяти, и что реализация будет оптимизирована таким образом, как будто вы
писали это вручную.

# Типаж `Stream`

Предварительно мы рассмотрели типаж [Future](https://docs.rs/futures/0.1.3/futures/trait.Future.html), который
полезен в случае вычисления всего лишь одного значения в течение всего времени. Но иногда вычисления лучше
представить в виде *потока* значений. Для примера, TCP слушатель
производит множество TCP соединений в течение своего времени жизни. Посмотрим, какие сущности из стандартной
библиотеки эквиваленты [Future](https://docs.rs/futures/0.1.3/futures/trait.Future.html) и
[Stream](https://docs.rs/futures/0.1.3/futures/stream/trait.Stream.html):


| # items | Sync | Async      | Common operations                              |
| ----- | -----  | ---------- | ---------------------------------------------- |
| 1 | [Result]   | [Future] | [map], [and_then]                        |
| ∞ | [Iterator] | [Stream] | [map][stream-map], [fold], [collect]   |

Взглянем на типаж [Stream](https://docs.rs/futures/0.1.3/futures/stream/trait.Stream.html):

```rust
trait Stream {
    type Item;
    type Error;

    fn poll(&mut self) -> Poll<Option<Self::Item>, Self::Error>;
}
```

Вы могли заметить, что типаж [Stream](https://docs.rs/futures/0.1.3/futures/stream/trait.Stream.html) очень
похож на типаж [Future](https://docs.rs/futures/0.1.3/futures/trait.Future.html). Основным отличием является
то, что метод [poll](https://docs.rs/futures/0.1.3/futures/stream/trait.Stream.html#tymethod.poll) возвращает
`Option<Self::Item>`, а не `Self::Item`.

[Stream](https://docs.rs/futures/0.1.3/futures/stream/trait.Stream.html) со временем производит множество
опциональных значений, сигнализируя о завершении потока возвратом `Poll::Ok(None)`. По своей сути
[Stream](https://docs.rs/futures/0.1.3/futures/stream/trait.Stream.html) представляет собой асинхронный поток,
который производит значения в определённом порядке.

На самом деле, [Stream](https://docs.rs/futures/0.1.3/futures/stream/trait.Stream.html) - это специальный
экземпляр
типажа [Future](https://docs.rs/futures/0.1.3/futures/trait.Future.html), и он может быть конвертирован в
future при помощи метода
[into_future](https://docs.rs/futures/0.1.3/futures/stream/trait.Stream.html#method.into_future). [Возвращённый
future](https://docs.rs/futures/0.1.3/futures/stream/struct.StreamFuture.html) получает следующее
значение из потока плюс сам поток, позволяющий получить больше значений позже. Это также позволяет составлять потоки
и остальные произвольные futures с помощью базовых комбинаторов future.

Как и типаж [Future](https://docs.rs/futures/0.1.3/futures/trait.Future.html), типаж
[Stream](https://docs.rs/futures/0.1.3/futures/stream/trait.Stream.html) обеспечивает большое количество
комбинаторов. Помимо future-подобных комбинаторов (например,
[then](https://docs.rs/futures/0.1.3/futures/stream/trait.Stream.html#method.then)) поддерживаются
потоко-специфичные комбинаторы, такие как
[fold](https://docs.rs/futures/0.1.3/futures/stream/trait.Stream.html#method.fold).

## Пример использования типажа `Stream`

Пример использования futures рассматривался в начале этого руководства, а сейчас посмотрим на пример
использования потоков, применив реализацию метода
[incoming](https://tokio-rs.github.io/tokio-core/tokio_core/net/struct.TcpListener.html#method.incoming). Этот
простой сервер, который принимает соединения, пишет слово "Hello!" и закрывает сокет:

```rust
extern crate futures;
extern crate tokio_core;

use futures::stream::Stream;
use tokio_core::reactor::Core;
use tokio_core::net::TcpListener;

fn main() {
    let mut core = Core::new().unwrap();
    let address = "127.0.0.1:8080".parse().unwrap();
    let listener = TcpListener::bind(&address, &core.handle()).unwrap();

    let addr = listener.local_addr().unwrap();
    println!("Listening for connections on {}", addr);

    let clients = listener.incoming();
    let welcomes = clients.and_then(|(socket, _peer_addr)| {
        tokio_core::io::write_all(socket, b"Hello!\n")
    });
    let server = welcomes.for_each(|(_socket, _welcome)| {
        Ok(())
    });

    core.run(server).unwrap();
}
```

Как и ранее, пройдёмся по строкам:

```rust
let mut core = Core::new().unwrap();
let address = "127.0.0.1:8080".parse().unwrap();
let listener = TcpListener::bind(&address, &core.handle()).unwrap();
```

Здесь мы инициализировали цикл событий, вызвав метод
[TcpListener::bind](https://tokio-rs.github.io/tokio-core/tokio_core/net/struct.TcpListener.html#method.bind) у
[LoopHandle](https://tokio-rs.github.io/tokio-core/tokio_core/reactor/struct.Core.html#method.handle) для создания TCP
слушателя, который будет принимать сокеты.

Далее взглянем на следующий код:

```rust
let server = listener.and_then(|listener| {
    // ...
});
```

Здесь видно, что
[TcpListener::bind](https://tokio-rs.github.io/tokio-core/tokio_core/net/struct.TcpListener.html#method.bind), как и
[TcpStream::connect](https://tokio-rs.github.io/tokio-core/tokio_core/net/struct.TcpStream.html#method.connect), не
возвращает [TcpListener](https://tokio-rs.github.io/tokio-core/tokio_core/net/struct.TcpListener.html), скорее, future его
вычисляет. Затем мы используем метод
[and_then](https://docs.rs/futures/0.1.3/futures/trait.Future.html#method.and_then) у
[Future](https://docs.rs/futures/0.1.3/futures/trait.Future.html), чтобы определить, что случится,
когда TCP слушатель станет доступным.

Мы получили TCP слушатель и можем определить его состояние:

```rust
let addr = listener.local_addr().unwrap();
println!("Listening for connections on {}", addr);
```

Вызываем метод
[local_addr](https://tokio-rs.github.io/tokio-core/tokio_core/net/struct.TcpStream.html#method.local_addr) для печати
адреса, с которым связали слушатель. С этого момента порт успешно связан, так что клиенты могут
подключиться.

Далее создадим [Stream](https://docs.rs/futures/0.1.3/futures/stream/trait.Stream.html).

```rust
let clients = listener.incoming();
```

Здесь метод [incoming](https://tokio-rs.github.io/tokio-core/tokio_core/net/struct.TcpListener.html#method.incoming)
возвращает [Stream](https://docs.rs/futures/0.1.3/futures/stream/trait.Stream.html) пары
[TcpListener](https://tokio-rs.github.io/tokio-core/tokio_core/net/struct.TcpListener.html) и
[SocketAddr](https://doc.rust-lang.org/std/net/enum.SocketAddr.html).
Это похоже на [TcpListener из стандартной библиотеки](https://doc.rust-lang.org/std/net/struct.TcpListener.html)
и [метод accept](https://doc.rust-lang.org/std/net/struct.TcpListener.html#method.accept), только в данном случае
мы, скорее, получаем все события в виде потока, а не принимаем сокеты вручную.

Поток `clients` производит сокеты постоянно. Это отражает работу серверов - они принимают клиентов в цикле и направляют
их в остальную часть системы для обработки.

Теперь, имея поток клиентских соединений, мы можем манипулировать им при помощи стандартных методов типажа
[Stream](https://docs.rs/futures/0.1.3/futures/stream/trait.Stream.html):

```rust
let welcomes = clients.and_then(|(socket, _peer_addr)| {
    tokio_core::io::write_all(socket, b"Hello!\n")
});
```

Здесь мы используем метод
[and_then](https://docs.rs/futures/0.1.3/futures/stream/trait.Stream.html#method.and_then) типажа
[Stream](https://docs.rs/futures/0.1.3/futures/stream/trait.Stream.html), чтобы выполнить действие над каждым
элементом потока. В данном случае мы формируем цепочку вычислений для каждого элемента потока (`TcpStream`). Мы видели
метод [write_all](https://tokio-rs.github.io/tokio-core/tokio_core/io/fn.write_all.html) ранее, он записывает
переданный буфер данных в переданный сокет.

Этот блок означает, что `welcomes` теперь является потоком сокетов, в которые записана последовательность символов
"Hello!". В рамках этого руководства мы завершаем работу с соединением, так что преобразуем весь поток `welcomes` в
future с помощью метода
[for_each](https://docs.rs/futures/0.1.3/futures/stream/trait.Stream.html#method.for_each):

```rust
welcomes.for_each(|(_socket, _welcome)| {
    Ok(())
})
```

Здесь мы принимаем результаты предыдущего future,
[write_all](https://tokio-rs.github.io/tokio-core/tokio_core/io/fn.write_all.html), и отбрасываем их, в результате чего
сокет закрывается.

Следует отметить, что важным ограничением этого сервера является отсутствие параллельности. Потоки
представляют собой упорядоченную обработку данных, и в данном случае порядок исходного потока -
это порядок, в котором сокеты были получены,
а методы [and_then](https://docs.rs/futures/0.1.3/futures/stream/trait.Stream.html#method.and_then) и
[for_each](https://docs.rs/futures/0.1.3/futures/stream/trait.Stream.html#method.for_each) этот порядок
сохраняют. Таким образом, сцепление(chaining) создаёт эффект, когда берётся каждый сокет из потока и обрабатываются все
связанные операции на нём перед переходом к следующем сокету.

Если, вместо этого, мы хотим управлять всеми клиентами паралельно, мы можем использовать метод
[spawn](https://tokio-rs.github.io/tokio-core/tokio_core/reactor/struct.Handle.html#method.spawn):

```rust
let clients = listener.incoming();
let welcomes = clients.map(|(socket, _peer_addr)| {
    tokio_core::io::write_all(socket, b"hello!\n")
});
let handle = core.handle();
let server = welcomes.for_each(|future| {
    handle.spawn(future.then(|_| Ok(())));
    Ok(())
});
```

Вместо метода [and_then](https://docs.rs/futures/0.1.3/futures/stream/trait.Stream.html#method.and_then)
используется метод [map](https://docs.rs/futures/0.1.3/futures/stream/trait.Stream.html#method.map), который
преобразует поток клиентов в поток futures. Затем мы изменяем замыкание переданное в
[for_each](https://docs.rs/futures/0.1.3/futures/stream/trait.Stream.html#method.for_each) используя метод
[spawn](https://tokio-rs.github.io/tokio-core/tokio_core/reactor/struct.Handle.html#method.spawn), что
позволяет future быть запущенным параллельно в цикле событий. Обратите внимание, что
[spawn](https://tokio-rs.github.io/tokio-core/tokio_core/reactor/struct.Handle.html#method.spawn) требует future
c item/error имеющими тип `()`.

# Конкретные реализации futures и потоков

На данном этапе имеется ясное понимание типажей [Future] и [Stream], того, как они реализованы и как их
совмещать. Но откуда все эти futures изначально пришли?
Взглянем на несколько конкретных реализаций futures и потоков.

Первым делом, любое доступное значение future находится в состоянии "готового". Для этого достаточно функций
[done](https://docs.rs/futures/0.1.3/futures/fn.done.html),
[failed](https://docs.rs/futures/0.1.3/futures/fn.failed.html) и
[finished](https://docs.rs/futures/0.1.3/futures/fn.finished.html). Функция
[done](https://docs.rs/futures/0.1.3/futures/fn.done.html) принимает `Result<T,E>` и возвращает
`Future<Item=I, Error=E>`. Для функций [failed](https://docs.rs/futures/0.1.3/futures/fn.failed.html) и
[finished](https://docs.rs/futures/0.1.3/futures/fn.finished.html) можно указать `T` или `E` и оставить другой
ассоцированный тип в качестве шаблона (wildcard).

Для потоков эквивалентным понятием "готового" значения потока является функция
[iter](https://docs.rs/futures/0.1.3/futures/stream/fn.iter.html), которая создаёт поток, отдающий элементы
полученного итератора. В ситуациях, когда значение не находится в состоянии "готового", также имеется много общих
реализаций [Future](https://docs.rs/futures/0.1.3/futures/trait.Future.html) и
[Stream](https://docs.rs/futures/0.1.3/futures/stream/trait.Stream.html), первая из которых - функция
[oneshot](https://docs.rs/futures/0.1.3/futures/fn.oneshot.html):

```rust
extern crate futures;

use std::thread;
use futures::Future;

fn expensive_computation() -> u32 {
    // ...
    200
}

fn main() {
    let (tx, rx) = futures::oneshot();

    thread::spawn(move || {
        tx.complete(expensive_computation());
    });

    let rx = rx.map(|x| x + 3);
}
```

Здесь видно, что функция [oneshot](https://docs.rs/futures/0.1.3/futures/fn.oneshot.html) возвращает
кортеж из двух элементов, как, например, [mpsc::channel](https://doc.rust-lang.org/std/sync/mpsc/fn.channel.html).
Первая часть `tx` ("transmitter") имеет тип [Complete](https://docs.rs/futures/0.1.3/futures/struct.Complete.html)
и используется для завершения `oneshot`, обеспечивая значение future на другом конце. Метод
[Complete::complete](https://docs.rs/futures/0.1.3/futures/struct.Complete.html#method.complete) передаст значение
принимающей стороне.

Вторая часть кортежа, это `rx` ("receiver"), имеет тип
[Oneshot](https://docs.rs/futures/0.1.3/futures/struct.Oneshot.html), для которого реализован типаж
[Future](https://docs.rs/futures/0.1.3/futures/trait.Future.html). `Item` имеет тип `T`, это тип `Oneshot`.
`Error` имеет тип [Canceled](https://docs.rs/futures/0.1.3/futures/struct.Canceled.html), что происходит, когда
часть [Complete](https://docs.rs/futures/0.1.3/futures/struct.Complete.html) отбрасывается не завершая выполнения
вычислений.

Эта конкретная реализация future может быть использована (как здесь показано) для передачи значений между потоками.
Каждая часть реализует типаж `Send` и по отдельности является владельцем сущности. Часто использовать эту реализацию,
как правило, не рекомендуется, лучше использовать базовые future и комбинаторы, там где это возможно.

Для типажа [Stream](https://docs.rs/futures/0.1.3/futures/stream/trait.Stream.html) доступен аналогичный примитив
[channel](https://docs.rs/futures/0.1.3/futures/stream/fn.channel.html). Этот тип также имеет две части, одна из
которых используется для отправки сообщений, а другая, реализующая `Stream`, для их приёма.

Канальный тип [Sender](https://docs.rs/futures/0.1.3/futures/stream/struct.Sender.html) имеет важное отличие от
стандартной библиотеки: когда значение отправляется в канал, он потребляет отправителя, возвращая future, который, в
свою очередь, возвращает исходного отправителя только когда посланное значение будет потреблено. Это
создаёт противодействие, чтобы производитель не смог совершить прогресс пока потребитель от него отстаёт.

# Возвращение futures

Самое необходимое действие в работе с futures - это возвращение
[Future](https://docs.rs/futures/0.1.3/futures/trait.Future.html). Однако как и с типажом
[Iterator](https://doc.rust-lang.org/std/iter/trait.Iterator.html), это пока что не так уж легко.
Рассмотрим имеющиеся варианты:

- [Типажи-объекты](https://github.com/alexcrichton/futures-rs/blob/master/TUTORIAL.md#trait-objects);
- [Пользовательские типы](https://github.com/alexcrichton/futures-rs/blob/master/TUTORIAL.md#custom-types);
- [Именованные типы](https://github.com/alexcrichton/futures-rs/blob/master/TUTORIAL.md#named-types);
- [impl Trait](https://github.com/alexcrichton/futures-rs/blob/master/TUTORIAL.md#impl-trait).

## Типажи-объекты

Первое, что можно сделать, это вернуть упакованный
[типаж-объект](http://rurust.github.io/rust_book_ru/src/trait-objects.html):

```rust
fn foo() -> Box<Future<Item = u32, Error = io::Error>> {
    // ...
}
```

Достоинством этого подхода является простая запись и создание. Этот подход максимально гибок с точки зрения изменений
future, так как любой тип future может быть возвращен в непрозрачном, упакованном виде.

Обратите внимание, что метод [boxed](https://docs.rs/futures/0.1.3/futures/trait.Future.html#method.boxed)
возвращает `BoxFuture`, который на самом деле является всего лишь псевдонимом для `Box<Future + Send>`:

```rust
fn foo() -> BoxFuture<u32, u32> {
    finished(1).boxed()
}
```

Недостатком такого подхода является выделение памяти в ходе исполнения, когда future создаётся. `Box` будет выделен в
куче, а future будет помещён внутрь. Однако, стоит заметить, что это единственное выделение памяти, и в ходе
выполнения future выделений более не будет. Более того, стоимость этой операции в конечном счёте не всегда высокая, так
как внутри нет упакованных future (т.е цепочка комбинаторов, как правило, не требует выделения памяти), и данный минус
относится только к внешнему `Box`.

## Пользовательские типы

Если вы не хотите возвращать `Box`, можете обернуть future в свой тип и возвращать его.

Пример:

```rust
struct MyFuture {
    inner: Oneshot<i32>,
}

fn foo() -> MyFuture {
    let (tx, rx) = oneshot();
    // ...
    MyFuture { inner: tx }
}

impl Future for MyFuture {
    // ...
}
```

В этом примере возвращается пользовательский тип `MyFuture` и для него реализуется типаж `Future`.
Эта реализация использует future `Oneshot<i32>`, но можно использовать любой другой future из контейнера.

Достоинством такого подхода является, то, что он не требует выделения памяти для `Box` и по-прежнему максимально гибок.
Детали реализации `MyFuture` скрыты, так что он может меняться не ломая остального.

Недостаток такого подхода в том, что он не всегда может быть эргономичным. Объявление новых типов становится
слишком громоздким через некоторое время, и при частом возвращении futures это может стать проблемой.

## Именованные типы

Следующая возможная альтернатива - именование возврашаемого типа напрямую:

```rust
fn add_10<F>(f: F) -> Map<F, fn(i32) -> i32>
    where F: Future<Item = i32>,
{
    fn do_map(i: i32) -> i32 { i + 10 }
    f.map(do_map)
}
```

Здесь возвращаемый тип именуется так, как компилятор видит его. Функция
[map](https://docs.rs/futures/0.1.3/futures/struct.Map.html) возвращает структуру
[map](https://docs.rs/futures/0.1.3/futures/struct.Map.html), которая содержит внутри future и функцию, которая
вычисляет значения для `map`.

Достоинством данного подхода является его эргономичность в отличие от пользовательских типов future, а также отсутствие
накладных расходов во время выполнения связанных с `Box`, как это было ранее.

Недостатком данного подхода можно назвать сложность именования возвращаемых типов. Иногда типы могут быть довольно-таки
большими. Здесь используется указатель на функцию (`fn(i32) -> i32`), но в идеале мы должны использовать замыкание.
К сожалению, на данный момент в типе возвращаемого значения не может присутствовать замыкание.

## `impl Trait`

Благодаря новой возможности в Rust, называемой
[impl Trait](https://github.com/rust-lang/rfcs/blob/master/text/1522-conservative-impl-trait.md), возможен ещё один
вариант возвращения future.

Пример:

```rust
fn add_10<F>(f: F) -> impl Future<Item = i32, Error = F::Error>
    where F: Future<Item = i32>,
{
    f.map(|i| i + 10)
}
```

Здесь мы указываем, что возвращаемый тип - это "нечто, реализующее типаж `Future`" с учётом указанных ассоциированных
типов. При этом использовать комбинаторы future можно как обычно.

Достоинством данного подхода является нулевая стоимость: нет необходимости упаковки в `Box`, он максимально гибок, так
как реализации future скрывают возвращаемый тип и эргономичность написания настолько же хороша, как и в первом примере
с `Box`.

Недостатком можно назвать, то что возможность
[impl Trait](https://github.com/rust-lang/rfcs/blob/master/text/1522-conservative-impl-trait.md) пока не входит в
стабильную версию Rust. Хорошие новости в том, что как только она войдёт в стабильную сборку, все контейнеры,
использующие futures, смогут немедленно ею воспользоваться. Они должны быть обратно-совместимыми, чтобы сменить типы
возвращаемых значений с `Box` на `impl Trait`.

# `Task` и `Future`

До сих пор мы говорили о том, как строить вычисления посредством создания futures, но мы едва ли коснулись того, как их
запускать. Ранее, когда разговор шёл о методе `poll`, было отмечено, что если `poll` возвращает `NotReady`, он
обеспечивает отправку уведомления задаче, но откуда эта задача вообще взялась? Кроме того, где `poll` был вызван впервые?

Рассмотрим [Task](https://docs.rs/futures/0.1.3/futures/task/struct.Task.html).

Структура [Task](https://docs.rs/futures/0.1.3/futures/task/struct.Task.html) управляет вычислениями,
представленными futures. Любой конкретный экземпляр future может иметь короткий цикл жизни, являясь частью большого
вычисления. В примере "Здраствуй, мир!" имелось некоторое количество future, но только один выполнялся в момент времени.
Для всей программы был один [Task](https://docs.rs/futures/0.1.3/futures/task/struct.Task.html), который следовал
логическому "потоку исполнения" по мере того, как обрабатывался каждый future и общее вычисление прогрессировало.

Когда future
[порождается](https://tokio-rs.github.io/tokio-core/tokio_core/reactor/struct.Handle.html#method.spawn) она сливается с
задачей и тогда эта структура может быть опрошена для завершения. Как и когда именно происходит опрос (poll),
остаётся во власти функции, которая запустила future. Обычно вы не будете вызывать
[spawn](https://tokio-rs.github.io/tokio-core/tokio_core/reactor/struct.Handle.html#method.spawn), а скорее
[СpuPool::spawn](https://docs.rs/futures/0.1.3/futures_cpupool/struct.CpuPool.html#method.spawn) с пулом потоков
или [Handle::spawn](https://tokio-rs.github.io/tokio-core/tokio_core/reactor/struct.Handle.html#method.spawn) с циклом
событий. Внутри они использут
[spawn](https://tokio-rs.github.io/tokio-core/tokio_core/reactor/struct.Handle.html#method.spawn) и обрабатывают
управляющие вызовы `poll` за вас.


В продуманной реализации типажа `Task` кроется эффективность контейнера `futures`: когда `Task` создан, все `Future`
в цепочке вычислений объединяются в машину состояний и переносятся из стека в кучу. Это действие является
единственным, которое требует выделение памяти в контейнере `futures`. В результате `Task` ведёт себя таким образом,
как если бы вы написали машину состояний вручную, в качестве последовательности прямолинейных вычислений.

# Локальные данные задачи

В предыдущем разделе мы увидели, что каждый отдельный future является частью большого асинхронного вычисления. Это
означает, что futures приходят и уходят, но может возникнуть необходимость, чтобы у них был доступ к данным, которые
живут на протяжении всего времени выполнения программы.

Futures требуют `'static`, так что у нас есть два варианта для обмена данными между futures:

- если данные будут использованы только одним future в момент времени, то мы можем передавать владение данными между
каждым future, которому потребуется доступ к данным;

- если доступ к данным должен быть параллельным, мы могли бы обернуть их в счётчик ссылок (`Arc / Rc`) или, в худшем
случае, ещё и в мьютекс (`Arc<Mutex>`), если нам потребуется изменять их.

Оба эти решения относительно тяжеловесны, поэтому посмотрим, сможем ли мы сделать лучше.

В разделе `Task` и `Future` мы увидели, что асинхронные вычисления имеют доступ к `Task` на всём протяжении его жизни,
и из сигнатуры метода `poll` было видно, что это изменяемый доступ. API `Task` использует эти особенности и позволяет
хранить данные внутри `Task`. Данные ассоциированные с `Task` могут быть созданы с помощью двух методов:

- макрос `task_local!`, очень похожий на макрос `thread_local!` из стандартной библиотеки. Данные, которые
инициализируются этим способом, будут лениво инициализироваться при первом доступе к `Task`,
а уничтожаться они будут, когда `Task` будет уничтожен;

- структура [TaskRc](https://docs.rs/futures/0.1.3/futures/task/struct.TaskRc.html) обеспечивает возможность
создания счётчика ссылок на данные, которые доступны только в соответствующей задаче. Она может быть клонирована,
так же как и `Rc`.

Примечательно, что оба эти метода объединяют данные с текущей запущенной задачей, что не всегда может быть желательно,
поэтому их следует использовать осторожно.
