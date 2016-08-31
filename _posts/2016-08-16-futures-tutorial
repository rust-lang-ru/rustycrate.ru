---
layout: post
categories: обучение
title: "futures-rs: асинхронщина на `Rust`"
author: Alex Crichton (перевёл Галимов Арсен aka "Loo Maclin")
excerpt: В данной статье будет представлен перевод официального руководства по достаточно молодой библиотеке 
`futures-rs`, которая имеет все предпосылки стать важной частью экосистемы `Rust`.

---

#Начинаем работу с `futures`

Этот документ поможет вам изучить контейнер для языка программирования `Rust` - `futures`, 
который обеспечивает реализацию futures и потоков с нулевой стоимостью.
Futures доступны во многих других языках программирования, таких как `C++`, `Java`, и `Scala`, и контейнер `futures`
черпает вдохновение из библиотек этих языков. Однако он отличается эргономичностью, а также
придерживается философии `Rust` абстракций с нулевой стоимостью. А именно, для создания и композиции futures не 
требуется выделений памяти, а для `Task`, управляющего ими, нужна только одна аллокация. Futures
предназначены стать основой для построения асинхронного, компонуемого, высоко производительного ввода/вывода в `Rust`, и
ранние замеры производительности показывают, что простой HTTP сервер, построенный на futures, действительно быстр!

Эта документация разделена на несколько разделов:

- "Здраствуй, мир!";
- типаж future;
- типаж `Stream`;
- конкретные futures и поток;
- возвращение futures;
- `Task` и future;
- локальные данные задачи;
- данные цикла событий.

#Здравствуй, мир!

Контейнер `futures` требует `Rust` версии 1.9.0 или выше, который может быть легко установлен с помощью `rustup`.
На Windows, macOS, и Linux протестировано и, как известно, работает, но PRs для остальных платформ всегда 
приветствуются! Вы можете добавить `futures` в `Cargo.toml` своего проекта следующим образом:

```

[dependencies]
futures = { git = "https://github.com/alexcrichton/futures-rs" }
tokio-core = { git = "https://github.com/tokio-rs/tokio-core" }
tokio-tls = { git = "https://github.com/tokio-rs/tokio-tls" }

```

> Примечание: эта библиотека в активной разработке и требует сливаний с git напрямую, но позже контейнер будет
опубликован на crates.io.

Здесь мы добавляем в зависимости четыре контейнера:

- [futures](https://github.com/alexcrichton/futures-rs) - определение и ядро реализации future и `Stream`;
- [tokio-core](https://github.com/tokio-rs/tokio-core) - привязка к контейнеру `mio`, предоставляющая конкретные 
реализации `Future` и `Stream` для TCP и UDP;
- [tokio-tls](https://github.com/tokio-rs/tokio-tls) - реализация SSL/TLS на основе futures.

Контейнер [futures](https://github.com/alexcrichton/futures-rs) является низкоуровневой реализацией futures, 
который не несёт в себе какой-либо среды выполнения или слоя ввода/вывода. Для примеров ниже мы используем 
конкретные реализации, доступные в [tokio-core](https://github.com/tokio-rs/tokio-core), 
чтобы показать, как futures и потоки 
могут быть использованы для выполнения сложных операций ввода/вывода с нулевыми накладными расходами на абстракции.

Теперь, когда у нас есть всё необходимое, напишем первую программу! В качестве hello-world примера скачаем домашнюю
страницу `Rust`:

```rust

extern crate futures;
extern crate tokio_core;
extern crate tokio_tls;

use std::net::ToSocketAddrs;

use futures::Future;
use tokio_core::Loop;
use tokio_tls::ClientContext;

fn main() {
    let mut lp = Loop::new().unwrap();
    let addr = "www.rust-lang.org:443".to_socket_addrs().unwrap().next().unwrap();

    let socket = lp.handle().tcp_connect(&addr);

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

    let (_, data) = lp.run(response).unwrap();
    println!("{}", String::from_utf8_lossy(&data));
}

```

Если вы положите файл с таким содержанием по пути `src/main.rs` и запустите команду `cargo run`, вы увидите HTML
главной страницы `Rust`.

> Примечание: rustc 1.10 компилирует этот пример медленно. С 1.11 построение происходит быстрее.

Этот код слишком большой, чтобы разобраться в нём с ходу, так что давайте пройдёмся построчно.
Взглянем на функцию `main()`:

```rust

let mut lp = Loop::new().unwrap();
let addr = "www.rust-lang.org:443".to_socket_addrs().unwrap().next().unwrap();

```

Здесь мы создаём [цикл событий](http://alexcrichton.com/futures-rs/futures_mio/struct.Loop.html#method.new), в
котором будем выполнять весь ввод/вывод. После мы преобразуем имя хоста 
["www.rust-lang.org"](https://www.rust-lang.org) с использованием метода `to_socket_addrs` из стандартной библиотеки.

Далее:

```rust

let socket = lp.handle().tcp_connect(&addr);

```

Мы [получаем хэндл](http://alexcrichton.com/futures-rs/futures_mio/struct.Loop.html#method.handle) цикла событий и
соединяемся с хостом при помощи 
[tcp_connect](http://alexcrichton.com/futures-rs/futures_mio/struct.LoopHandle.html#method.tcp_connect).
Примечательно, что 
[tcp_connect](http://alexcrichton.com/futures-rs/futures_mio/struct.LoopHandle.html#method.tcp_connect) возвращает
future! В действительности, сокет не подключен, но подключение произойдёт позже.

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

Здесь мы используем метод [and_then](http://alexcrichton.com/futures-rs/futures/trait.Future.html#method.and_then)
типажа future, вызывая его у результата выполнения метода 
[tcp_connect](http://alexcrichton.com/futures-rs/futures_mio/struct.LoopHandle.html#method.tcp_connect). Метод 
[tcp_connect](http://alexcrichton.com/futures-rs/futures_mio/struct.LoopHandle.html#method.tcp_connect) принимает 
замыкание, которое получает значение предыдущего future. В этом случае `socket` будет иметь тип
[TcpStream](http://alexcrichton.com/futures-rs/futures_mio/struct.TcpStream.html). Стоит отметить, что замыкание,
переданное в [and_then](http://alexcrichton.com/futures-rs/futures/trait.Future.html#method.and_then) не будет
выполнено в случае, если 
[tcp_connect](http://alexcrichton.com/futures-rs/futures_mio/struct.LoopHandle.html#method.tcp_connect) вернёт
ошибку.

Как только получен `socket`, мы создаём клиентский TLS контекст с помощью 
[ClientContext::new](http://alexcrichton.com/futures-rs/futures_tls/struct.ClientContext.html#method.new). Этот тип 
из контейнера `tokio-tls` представляет клиентскую 
часть TLS соединения. Далее вызываем метод 
[handshake](http://alexcrichton.com/futures-rs/futures_tls/struct.ClientContext.html#method.handshake), 
чтобы выполнить TLS хэндшейк. Первый аргумент - доменное имя, к которому мы подключаемся, второй - объект 
ввода/вывода (в данном случае объект `socket`). 

Как и [tcp_connect](http://alexcrichton.com/futures-rs/futures_mio/struct.LoopHandle.html#method.tcp_connect)
ранее, метод [handshake](http://alexcrichton.com/futures-rs/futures_tls/struct.ClientContext.html#method.handshake) 
возвращает future. TLS хэндшэйк может занять некоторое время, потому что клиенту и серверу необходимо 
выполнить некоторый ввод/вывод, подтверждение сертификатов и т.д. После выполнения future вернёт 
`http://alexcrichton.com/futures-rs/futures_tls/struct.TlsStream.html`, похожий на расмотренный выше 
[TcpStream](http://alexcrichton.com/futures-rs/futures_mio/struct.TcpStream.html).

Комбинатор [and_then](http://alexcrichton.com/futures-rs/futures/trait.Future.html#method.and_then) выполняет
много скрытой работы, обеспечивая выполнение futures в правильном порядке и отслеживая их на лету. 
При этом значение, возвращаемое 
[and_then](http://alexcrichton.com/futures-rs/futures/trait.Future.html#method.and_then), реализует типаж 
[Future](http://alexcrichton.com/futures-rs/futures/trait.Future.html), поэтому мы можем составлять цепочки 
вычислений.

Далее мы отравляем HTTP запрос:

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
[and_then](http://alexcrichton.com/futures-rs/futures/trait.Future.html#method.and_then) снова, чтобы продолжить 
вычисление. Комбинатор [write_all](http://alexcrichton.com/futures-rs/futures_io/fn.write_all.html) полностью 
записывает HTTP запрос, производя многократные записи по необходимости.

Future, возвращаемый методом [write_all](http://alexcrichton.com/futures-rs/futures_io/fn.write_all.html), будет 
выполнен, как только все данные будут записаны в сокет. Примечательно, что 
[TlsStream](http://alexcrichton.com/futures-rs/futures_tls/struct.TlsStream.html) скрыто шифрует все данные, которые 
мы записывали, перед тем как отправить в сокет.

Третья и последняя часть запроса выглядит так:

```rust

let response = request.and_then(|(socket, _)| {
    tokio_core::io::read_to_end(socket, Vec::new())
});

```

Предыдущий future `request` снова связан, на этот раз с результатом выполнения комбинатора 
[read_to_end](http://alexcrichton.com/futures-rs/futures_io/fn.read_to_end.html). Этот future будет читать все данные 
из сокета и помещать их в предоставленный буфер, и вернёт буфер, 
когда обрабатываемое соединение передаст EOF.

Как и ранее, чтение из сокета на самом деле скрыто расшифровывает данные, полученные от сервера, так что мы читаем 
расшифрованную версию.

Если запустить программу с этого места, вы удивитесь, потому что ничего не произойдёт, 
когда она запустится. Это потому что всё, что мы сделали, основано на future вычислениях, и мы на самом деле 
не запустили их. До этого момента мы не делали никакого ввода/вывода, и не выполняли HTTP запросов и т.д.

Чтобы по-настоящему запустить наши future и управлять ими до завершения, необходимо запустить цикл событий:

```rust

let (_, data) = lp.run(response).unwrap();
println!("{}", String::from_utf8_lossy(&data));

```

Здесь future `response` помещается в цикл событий, [запрашивая у него 
выполнения future](http://alexcrichton.com/futures-rs/futures/struct.Task.html#method.run). Цикл событий будет 
выполняться, пока результат не будет получен.

Примечательно, что вызов `lp.run(..)` блокирует вызывающий поток, пока future не сможет быть возвращен. Это 
означает, что `data` имеет тип `Vec<u8>`. Тогда мы можем напечатать это в stdout как обычно.

Фух! На данный момент мы уже видели futures, 
[инициализирующие TCP соедениение](http://alexcrichton.com/futures-rs/futures_mio/struct.LoopHandle.html#method.tcp_connect), 
[создающие цепочки вычислений](http://alexcrichton.com/futures-rs/futures/trait.Future.html#method.and_then) и 
[читающие данные из сокета](http://alexcrichton.com/futures-rs/futures_io/fn.read_to_end.html). Но это только пример 
возможностей futures, так давайте рассмотрим нюансы.

#Типаж future

Типаж future является ядром контейнера `futures`. Этот типаж представляет асинхронные вычисления и их результат. 
Взглянем на следующий код:

```rust

trait Future {
    type Item;
    type Error;

    fn poll(&mut self, task: &mut Task) -> Poll<Self::Item, Self::Error>;
    fn schedule(&mut self, task: &mut Task);

    // ...
}

```

Я уверен, что определение содержит ряд пунктов, вызывающих вопросы: 

- `Item` и `Error`;
- `poll`;
- комбинаторы future.

Разберём их детально.

## `Item` и `Error`

Первая особенность типажа future, как вы, вероятно, заметили, это то, что он содержит два ассоциированных типа. 
Они представляют собой типы значений, которые future может получить. Каждый экземпляр future можно обработать как 
`Result<Self::Item, Self::Error>`.

Эти два типа будут применяться очень часто в условиях `where` при потреблении futures, и в сигнатурах типа, когда 
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
          F::Item: Future,
{
    // ...
}

```

## `poll`

```rust

fn poll(&mut self, task: &mut Task) -> Poll<Self::Item, Self::Error>;

```

Работа типажа [Future](http://alexcrichton.com/futures-rs/futures/trait.Future.html) построена на этом методе. 
Метод [poll](http://alexcrichton.com/futures-rs/futures/trait.Future.html#tymethod.poll) - это единственная точка 
входа для извлечения вычисленного в future значения. Как пользователю `futures` вам редко понадобится вызывать этот 
метод напрямую. Скорее всего, вы будете взаимодействовать с futures через комбинаторы, которые создают 
высокоуровневые абстракции вокруг futures. Но это полезно для понимания того, как futures работают под капотом.

Давайте подробнее рассмотрим метод [poll](http://alexcrichton.com/futures-rs/futures/trait.Future.html#tymethod.poll). 
Обратим внимание на аргумент `&mut self`, который вызывает ряд ограничений и свойств:

- futures могут быть опрошены только одним потоком единовременно;
- во время выполнения метода `poll`, futures могут изменять своё состояние;
- после заврешения `poll` владение futures может быть передано другой сущности.

Взглянем на тип возвращаемого значения `Poll`, которое выглядит следующим образом:

```rust

enum Poll<T, E> {
    NotReady,
    Ok(T),
    Err(E),
}

```

Посредством этого перечисления futures могут взаимодействовать, принимая `Poll::Ok`, когда значение future готово 
к использованию или `Poll::Err`, когда в ходе вычислений произошла ошибка. Если значение ещё не доступно, будет 
возвращено `Poll::NotReady`.

Типаж [Future](http://alexcrichton.com/futures-rs/futures/trait.Future.html), как и `Iterator`, не определяет, что
происходит после вызова метода [poll](http://alexcrichton.com/futures-rs/futures/trait.Future.html#tymethod.poll), 
если future уже обработан. Это означает, что тем, кто реализует типаж 
[Future](http://alexcrichton.com/futures-rs/futures/trait.Future.html), не нужно поддерживать состояние, 
чтобы проверить, успешно ли вернул результат метод 
[poll](http://alexcrichton.com/futures-rs/futures/trait.Future.html#tymethod.poll).

Если вызов [poll](http://alexcrichton.com/futures-rs/futures/trait.Future.html#tymethod.poll) возвращает 
`Poll::NotReady`, future всё ещё требуется знать, когда необходимо выполниться снова.
Для достижения этой цели future должен обеспечить следующий механизм: при получении`NotReady`  
текущая задача должна иметь возможность получить уведомление, когда значение станет доступным. 

Метод `task::park` является основной входной точкой, чтобы доставлять уведомления. Эта функция возвращает 
[TaskHandler](http://alexcrichton.com/futures-rs/futures/struct.TaskHandle.html), который реализует типажи `Send` и 
`'static` и имеет основной метод - 
[unpark](http://alexcrichton.com/futures-rs/futures/struct.TaskHandle.html#method.unpark). Вызов метода 
[unpark](http://alexcrichton.com/futures-rs/futures/struct.TaskHandle.html#method.unpark) указаывает, что future
может производить вычисления и возвращать значение.

Более детальную документацию можно найти
[здесь](http://alexcrichton.com/futures-rs/futures/trait.Future.html#tymethod.poll).

## комбинаторы future

Теперь мы видим, что метод [poll](http://alexcrichton.com/futures-rs/futures/trait.Future.html#tymethod.poll) 
выглядит так, что его вызов может внести немного боли в ваш рабочий процесс. Что если у вас есть future, который 
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

Здесь мы используем [map](http://alexcrichton.com/futures-rs/futures/struct.Map.html), чтобы преобразовать 
future, возвращающий тип `String`, во future, возвращающий `u32`. Этот пример возвращает 
[Box](https://doc.rust-lang.org/std/boxed/struct.Box.html), но это не всегда необходимо и будет рассмотрено в разделе 
[возвращений futures](https://github.com/alexcrichton/futures-rs/blob/master/TUTORIAL.md#returning-futures).

Комбинаторы позволяют выражать следующие концепции:

- изменение типа future ([map](http://alexcrichton.com/futures-rs/futures/struct.Map.html), 
[map_err](http://alexcrichton.com/futures-rs/futures/trait.Future.html#method.map_err));
- запуск другого future, когда исходный будет выполнен (
[then](http://alexcrichton.com/futures-rs/futures/trait.Future.html#method.then), 
[and_then](http://alexcrichton.com/futures-rs/futures/trait.Future.html#method.and_then), 
[or_else](http://alexcrichton.com/futures-rs/futures/trait.Future.html#method.or_else));
- продолжение выполнения, когда хотя бы один из futures выполнился ( 
[select](http://alexcrichton.com/futures-rs/futures/trait.Future.html#method.select));
- ожидание выполнения двух future (
[join](http://alexcrichton.com/futures-rs/futures/trait.Future.html#method.join));
- определение поведения `poll` после вычислений (
[fuse](http://alexcrichton.com/futures-rs/futures/trait.Future.html#method.fuse)).

Использование комбинаторов должно быть похоже на использование типажа `Iterator` в Rust или `futures` в Scala.
Большинство манипуляций с futures заканчивается использованием этих комбинаторов. Все комбинаторы имеют нулевую 
стоимость, что означает отсутствие выделений памяти, и что реализация будет оптимизирована таким образом, как будто вы 
писали это вручную.

# типаж `Stream`

Предварительно мы рассмотрели типаж [Future](http://alexcrichton.com/futures-rs/futures/trait.Future.html), который 
полезен, если мы производим вычисления всего лишь одного значения в течение всего времени. Но иногда вычисления лучше 
представить в виде *потока* значений. Для примера, TCP слушатель 
производит множество TCP соединений в течение своего времени жизни. Посмотрим, какие сущности из стандартной 
библиотеки эквиваленты [Future](http://alexcrichton.com/futures-rs/futures/trait.Future.html) и 
[Stream](http://alexcrichton.com/futures-rs/futures/stream/trait.Stream.html):


| # items | Sync | Async      | Common operations                              |
| ----- | -----  | ---------- | ---------------------------------------------- |
| 1 | [Result]   | [Future] | [map], [and_then]                        |
| ∞ | [Iterator] | [Stream] | [map][stream-map], [fold], [collect]   |

Взглянем на типаж [Stream](http://alexcrichton.com/futures-rs/futures/stream/trait.Stream.html):

```rust

trait Stream {
    type Item;
    type Error;

    fn poll(&mut self) -> Poll<Option<Self::Item>, Self::Error>;
}

```

Вы могли заметить, что типаж [Stream](http://alexcrichton.com/futures-rs/futures/stream/trait.Stream.html) очень 
похож на типаж [Future](http://alexcrichton.com/futures-rs/futures/trait.Future.html). Основным отличием является 
то, что метод [poll](http://alexcrichton.com/futures-rs/futures/stream/trait.Stream.html#tymethod.poll) возвращает 
`Option<Self::Item>`, а не `Self::Item`.

[Stream](http://alexcrichton.com/futures-rs/futures/stream/trait.Stream.html) со временем производит множество 
опциональных значений, сигнализируя о завершении потока возвратом `Poll::Ok(None)`. По своей сути 
[Stream](http://alexcrichton.com/futures-rs/futures/stream/trait.Stream.html) представляет собой асинхронный поток, 
который производит значения в определённом порядке.

На самом деле, [Stream](http://alexcrichton.com/futures-rs/futures/stream/trait.Stream.html) - это специальный 
экземпляр 
типажа [Future](http://alexcrichton.com/futures-rs/futures/trait.Future.html), и он может быть конвертирован в 
future при помощи метода 
[into_future](http://alexcrichton.com/futures-rs/futures/stream/trait.Stream.html#method.into_future). [Возвращённый 
future](http://alexcrichton.com/futures-rs/futures/stream/struct.StreamFuture.html) получает следующее 
значение из потока плюс сам поток, позволяющий получить больше значений позже. Это также позволяет составлять потоки 
и остальные произвольные futures с помощью базовых комбинаторов future.

Как и типаж [Future](http://alexcrichton.com/futures-rs/futures/trait.Future.html), типаж 
[Stream](http://alexcrichton.com/futures-rs/futures/stream/trait.Stream.html) обеспечивает большое количество 
комбинаторов. В добавление к future-подобным комбинаторам (например, 
[then](http://alexcrichton.com/futures-rs/futures/stream/trait.Stream.html#method.then)) поддерживаются  
потоко-специфичные комбинаторы, такие как 
[fold](http://alexcrichton.com/futures-rs/futures/stream/trait.Stream.html#method.fold).

## Пример использования типажа `Stream`

Мы видели пример того, как использовать futures, в начале этого руководства, а сейчас посмотрим на пример 
использования потоков, применив реализацию метода 
[incoming](http://alexcrichton.com/futures-rs/futures_mio/struct.TcpListener.html#method.incoming). Этот 
простой сервер, который принимает соединения, пишет слово "Hello!" и закрывает сокет:

```rust

extern crate futures;
extern crate tokio_core;

use futures::Future;
use futures::stream::Stream;
use tokio_core::Loop;

fn main() {
    let mut lp = Loop::new().unwrap();
    let address = "127.0.0.1:8080".parse().unwrap();
    let listener = lp.handle().tcp_listen(&address);

    let server = listener.and_then(|listener| {
        let addr = listener.local_addr().unwrap();
        println!("Listening for connections on {}", addr);

        let clients = listener.incoming();
        let welcomes = clients.and_then(|(socket, _peer_addr)| {
            tokio_core::io::write_all(socket, b"Hello!\n")
        });
        welcomes.for_each(|(_socket, _welcome)| {
            Ok(())
        })
    });

    lp.run(server).unwrap();
}

```

Как и ранее, пройдёмся по строкам:

```rust

let mut lp = Loop::new().unwrap();
let address = "127.0.0.1:8080".parse().unwrap();
let listener = lp.handle().tcp_listen(&address);

```

Здесь мы инициализировали цикл событий, вызвав метод 
[tcp_listen](http://alexcrichton.com/futures-rs/futures_mio/struct.LoopHandle.html#method.tcp_listen) у 
[LoopHandle](http://alexcrichton.com/futures-rs/futures_mio/struct.LoopHandle.html) для создания TCP слушателя, 
который будет принимать сокеты.

Далее взглянем на следующий код:

```rust

let server = listener.and_then(|listener| {
    // ...
});

```

Здесь видно, что 
[tcp_listen](http://alexcrichton.com/futures-rs/futures_mio/struct.LoopHandle.html#method.tcp_listen), как и 
[tcp_connect](http://alexcrichton.com/futures-rs/futures_mio/struct.LoopHandle.html#method.tcp_connect), не 
возвращает [TcpListener](http://alexcrichton.com/futures-rs/futures_mio/struct.TcpListener.html), скорее, future его 
вычисляет. Затем мы используем метод 
[and_then](http://alexcrichton.com/futures-rs/futures/trait.Future.html#method.and_then) у 
[Future](http://alexcrichton.com/futures-rs/futures/trait.Future.html), чтобы определить, что случится, 
когда TCP слушатель станет доступным.

Теперь мы имеем TCP слушатель и можем определить его состояние:

```rust

let addr = listener.local_addr().unwrap();
println!("Listening for connections on {}", addr);

```

Вызываем метод 
[local_addr](http://alexcrichton.com/futures-rs/futures_mio/struct.TcpListener.html#method.local_addr) для печати 
адреса, с которым связали слушатель. С этого момента порт успешно связан, так что клиенты теперь могут 
подключиться.

Далее создадим [Stream](http://alexcrichton.com/futures-rs/futures/stream/trait.Stream.html).

```rust

let clients = listener.incoming();

```

Здесь метод [incoming](http://alexcrichton.com/futures-rs/futures_mio/struct.TcpListener.html#method.incoming) 
возвращает [Stream](http://alexcrichton.com/futures-rs/futures/stream/trait.Stream.html) пары 
[TcpListener](http://alexcrichton.com/futures-rs/futures_mio/struct.TcpListener.html) и 
[SocketAddr](https://doc.rust-lang.org/std/net/enum.SocketAddr.html). 
Это похоже на [TcpListener из стандартной библиотеки](https://doc.rust-lang.org/std/net/struct.TcpListener.html) 
и [метод accept](https://doc.rust-lang.org/std/net/struct.TcpListener.html#method.accept), только в данном случае
мы скорее получаем все события в виде потока, а не принимаем сокеты вручную.

Поток `clients` производит сокеты постоянно. Это отображает то, как сокет серверы обычно принимают клиентов 
в цикле и после направляют их в остальную часть системы обработки.

Теперь, имея поток клиентских соединений, мы можем манипулировать им при помощи стандартных методов типажа 
[Stream](http://alexcrichton.com/futures-rs/futures/stream/trait.Stream.html):

```rust

let welcomes = clients.and_then(|(socket, _peer_addr)| {
    tokio_core::io::write_all(socket, b"Hello!\n")
});

```

Здесь мы используем метод 
[and_then](http://alexcrichton.com/futures-rs/futures/stream/trait.Stream.html#method.and_then) типажа 
[Stream](http://alexcrichton.com/futures-rs/futures/stream/trait.Stream.html), чтобы выполнить действие над каждым 
элементом потока. В данном случае мы формируем цепочку вычислений для каждого элемента потока (`TcpStream`). В действии
метод [write_all](http://alexcrichton.com/futures-rs/futures_io/fn.write_all.html) мы видели ранее, он записывает 
переданный буфер данных в переданный сокет.

Этот блок означает, что `welcomes` теперь является потоком сокетов, в которые записана "Hello!" 
последовательность символов. В рамках этого руководства мы завершаем работу с соединением, так что  
преобразуем весь поток `welcomes` в future с помощью метода 
[for_each](http://alexcrichton.com/futures-rs/futures/stream/trait.Stream.html#method.for_each):

```rust

welcomes.for_each(|(_socket, _welcome)| {
    Ok(())
})

```

Сбрасываем результат выполнения предыдущего future 
[write_all](http://alexcrichton.com/futures-rs/futures_io/fn.write_all.html), закрывая сокет.

Следует отметить, что важным ограничением этого сервера является то, что отсутствует параллельность. Потоки 
представляют собой упорядоченную обработку данных, и в данном случае порядок исходного потока -  
это порядок, в котором сокеты были получены, 
а методы [and_then](http://alexcrichton.com/futures-rs/futures/stream/trait.Stream.html#method.and_then) и 
[for_each](http://alexcrichton.com/futures-rs/futures/stream/trait.Stream.html#method.for_each) этот порядок 
сохраняют. Таким образом, связывание создаёт эффект, когда берётся каждый сокет из потока и обрабатываются все 
связанные операции на нём перед переходом к следующем сокету.

Если, вместо этого, мы хотим управлять всеми клиентами паралельно, мы можем использовать метод 
[forget](http://alexcrichton.com/futures-rs/futures/trait.Future.html#method.forget):

```rust

let clients = listener.incoming();
let welcomes = clients.map(|(socket, _peer_addr)| {
    tokio_core::io::write_all(socket, b"Hello!\n")
});
welcomes.for_each(|future| {
    future.forget();
    Ok(())
})

```

Вместо метода [and_then](http://alexcrichton.com/futures-rs/futures/stream/trait.Stream.html#method.and_then) 
используется метод [map](http://alexcrichton.com/futures-rs/futures/stream/trait.Stream.html#method.map), который 
преобразует поток клиентов в поток futures. Изменяем замыкание, добавляя в него вызов метода 
[forget](http://alexcrichton.com/futures-rs/futures/trait.Future.html#method.forget), который позволяет запускать 
future паралельно.

# Конкретные реализации futures и потоков

На данном этапе имеется ясное понимание типажей [Future] и [Stream], того, как они реализованы и как их 
совмещать. Но откуда все эти futures изначально пришли?
Взглянем на несколько конкретных реализаций futures и потоков.

Первым делом, любое доступное значение future находится в состоянии "готового". Для этого достаточно функций 
[done](http://alexcrichton.com/futures-rs/futures/fn.done.html), 
[failed](http://alexcrichton.com/futures-rs/futures/fn.failed.html) и 
[finished](http://alexcrichton.com/futures-rs/futures/fn.finished.html). Функция 
[done](http://alexcrichton.com/futures-rs/futures/fn.done.html) принимает `Result<T,E>` и возвращает 
`Future<Item=I, Error=E>`. Для функций [failed](http://alexcrichton.com/futures-rs/futures/fn.failed.html) и 
[finished](http://alexcrichton.com/futures-rs/futures/fn.finished.html) можно указать `T` или `E` и оставить другой 
ассоцированный тип в качестве шаблона.

Для потоков, эквивалентным понятием "готового" значения потока является функция 
[iter](http://alexcrichton.com/futures-rs/futures/stream/fn.iter.html), которая создаёт поток, отдающий элементы 
полученного итератора. В ситуациях, когда значение не находится в состоянии "готового", также имеется много общих 
реализаций [Future](http://alexcrichton.com/futures-rs/futures/trait.Future.html) и 
[Stream](http://alexcrichton.com/futures-rs/futures/stream/trait.Stream.html), первая из которых - функция 
[oneshot](http://alexcrichton.com/futures-rs/futures/fn.oneshot.html). 
Давайте посмотрим:

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

Здесь видно, что функция [oneshot](http://alexcrichton.com/futures-rs/futures/fn.oneshot.html) возвращает 
кортеж из двух элементов, как, например, [mpsc::channel](https://doc.rust-lang.org/std/sync/mpsc/fn.channel.html).
Первая часть `tx` ("transmitter") имеет тип [complete](http://alexcrichton.com/futures-rs/futures/struct.Complete.html)
и используется для завершения `oneshot`, обеспечивая значение future на другом конце. Метод 
[Complete::complete](http://alexcrichton.com/futures-rs/futures/struct.Complete.html#method.complete) будет передавать 
значение на конце приёма.

Вторая часть кортежа, это `rx` ("receiver"), имеет тип 
[Oneshot](http://alexcrichton.com/futures-rs/futures/struct.Oneshot.html), для которого реализован типаж 
[Future](http://alexcrichton.com/futures-rs/futures/trait.Future.html). `Item` имеет тип `T`, это тип `oneshot`. 
`Error` имеет тип [Canceled](http://alexcrichton.com/futures-rs/futures/struct.Canceled.html), что происходит, когда 
часть [Complete](http://alexcrichton.com/futures-rs/futures/struct.Complete.html) отбрасывается не завершая выполнения 
вычислений.

Эта конкретная реализация future может быть использована (как здесь показано) для передачи значений между потоками.
Каждая часть реализует типаж `Send` и по отдельности является владельцом сущности. Частое использование этого как 
правило не рекомендуется, однако лучше использовать базовые future и комбинаторы, там где это возможно.

Для типажа [Stream](http://alexcrichton.com/futures-rs/futures/stream/trait.Stream.html) доступен аналогичный примитив 
[channel](http://alexcrichton.com/futures-rs/futures/stream/fn.channel.html). Этот тип так же имеет две части, одна из 
которых используется для отправки сообщений, а другая реализующая `Stream` для их приёма.

Канальный тип [Sender](http://alexcrichton.com/futures-rs/futures/stream/struct.Sender.html) имеет важное отличие от 
стандартной библиотеки: когда значение отправляется в канал он потребляет отправителя, возвращая future, который в 
свою очередь возвращает исходного отправителя, только после того как посланное значение будет потреблено. Это 
создаёт обратное давление (ОБРАТНОЕ ДАВЛЕНИЕ, СЕРЬЁЗНО? ТЫ ЧТО В ГУГЛЕ ПЕРЕВОДИЛ?), 
так что производитель не сможет совершить прогресс пока потребитель от него отстаёт.

# Возвращение futures

Когда приходится работать с futures, одна из вещей, которая действительно необходима - это возвращение 
[Future](http://alexcrichton.com/futures-rs/futures/trait.Future.html). Как и с типажом
[Iterator](https://doc.rust-lang.org/std/iter/trait.Iterator.html), это не самая простая вещь, 
которую можно сделать. Давайте взглянем на имеющиеся варианты:

- [Типажи-объекты](https://github.com/alexcrichton/futures-rs/blob/master/TUTORIAL.md#trait-objects)
- [Пользовательские типы](https://github.com/alexcrichton/futures-rs/blob/master/TUTORIAL.md#custom-types)
- [Именованные типы](https://github.com/alexcrichton/futures-rs/blob/master/TUTORIAL.md#named-types)
- [impl Trait](https://github.com/alexcrichton/futures-rs/blob/master/TUTORIAL.md#impl-trait)

## Типажи-объекты

Первое, что вы могли бы сделать, это вернуть упакованный 
[типаж-объект](http://rurust.github.io/rust_book_ru/src/trait-objects.html):

```rust

fn foo() -> Box<Future<Item = u32, Error = io::Error>> {
    // ...
}

```

Достоинством этого подхода является простая запись и создание. Этот подход максимально гибок с точки зрения 
изменений future, как и любой другой тип он может быть возвращён непрозрачно, а как упакованный `Future`.

Обратите внимание, что метод [boxed](http://alexcrichton.com/futures-rs/futures/trait.Future.html#method.boxed) 
возвращает `BoxFuture`, который на само деле является всего лишь псевдонимом для `Box<Future + Send>`:

```rust

fn foo() -> BoxFuture<u32, u32> {
    finished(1).boxed()
}

```

Недостатком такого подхода является выделение памяти в ходе исполнения, когда future создаётся. `Box` будет выделен в 
куче, а future будет помещён внутрь. Однако, стоит заметить, что это единственное выделение памяти здесь, и в ходе 
выполнения future, выделений более не будет. Более того, стоимость этой операции не всегда высокая и в конечном счёте 
внутри нет упакованных future (т.е цепь комбинаторов как правило не требует выделения памяти), и данный минус вступает 
в силу только при использовании `Box`.

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

В этом примере возвращается пользовательский тип `MyFuture` и для него реализуетсяя типаж `Future`.
Эта реализация использует future `Oneshot<i32>`, но можно использовать любой другой future из контейнера.

Достоинством такого подхода является, то, что он не требует выделения памяти для `Box` и остаётся по прежнему 
максимально гибким. Детали реализации `MyFuture` скрыты, так что он может быть изменён не ломая остального.

Недостаток такого подхода, выражается в том, что он не всегда может быть эргономичным. Объявление новых типов становится 
слишком громздким через некоторое время, и если вы очень часто хотите возвращться futures - это может стать проблемой.

## Именованные типы

Следующей возможной альтернативой является именование возврашаемого типа напрямую:

```rust

fn add_10<F>(f: F) -> Map<F, fn(i32) -> i32>
    where F: Future<Item = i32>,
{
    fn do_map(i: i32) -> i32 { i + 10 }
    f.map(do_map)
}

```

Здесь возвращаемый тип именуется, так как компилятор видит его. Функция 
[map](alexcrichton.com/futures-rs/futures/struct.Map.html) возвращает структуру 
[map](http://alexcrichton.com/futures-rs/futures/struct.Map.html), которая содержит внутри future и функцию которая 
вычисляет значения для `map`.

Достоинством данного подхода является его эргономичность в отличии от пользовательских типов future и так же отсутствие 
накладных расходов во время выполнения связанных с `Box`, как это было ранее.

Недостатком данного подхода можно назвать сложность именования возвращаемых типов. Иногда типы могут быть довольно таки 
большими. Здесь используется указатель на функцию (`fn(i32) -> i32`), но в идеале мы должны использовать замыкание. 
К сожалению, на данный момент в типе возвращаемого значения не может присутствовать замыкание.

## `impl Trait`

Благодаря новой возможности в Rust называемой 
[impl Trait](https://github.com/rust-lang/rfcs/blob/master/text/1522-conservative-impl-trait.md) возможен ещё один 
вариант возвращения future.

Пример:

```rust

fn add_10<F>(f: F) -> impl Future<Item = i32, Error = F::Error>
    where F: Future<Item = i32>,
{
    f.map(|i| i + 10)
}

```

Здесь мы указываем, что возвращаемый тип, это что то, что реализует типаж `Future`, с учётом указанных ассоциированных 
типов. При этом использовать комбинаторы future можно как обычно.

Достоинством данного подхода является нулевая стоимость: нет необходимости упаковки в `Box`, он максимально гибок, так 
как реализации future скрывают возвращаемый тип и эргономичность написания настолько же хороша, как и в первом примере 
с `Box`.

Недостатком можно назвать, то что возможность 
[impl Trait](https://github.com/rust-lang/rfcs/blob/master/text/1522-conservative-impl-trait.md) не входит в стабильную 
версию Rust. Хорошие новости в том, что как только она войдёт в стабильную сборку, все контейнеры использующие 
futures смогут немедленно ею воспользоваться. Они должны быть обратно-совместимым, чтобы сменить типы 
возвращаемых значений с `Box` на `impl Trait`.

# `Task` и `Future`

До сих пор мы говорили, о том, как строит вычисления посредством создания futures, но мы едва ли коснулись того, как их 
запускать. Ранее, когда разговор шёл о методе `poll` было отмечено, что если `poll` возвращает `NotReady` он заботится, 
об уведомлении задачи, но откуда эта задача вообще взялась? Кроме того, где `poll` был вызван впервые?

Рассмотрим [Task](http://alexcrichton.com/futures-rs/futures/task/struct.Task.html).

Структура [Task](http://alexcrichton.com/futures-rs/futures/task/struct.Task.html) управляет вычислениям, которые 
представляют futures. Любой конкретный экземпляр future может иметь короткий цикл жизни, являясь частью большого 
вычисления. В примере "Здраствуй, мир!" имелось некоторое количество future, но только один выполнялся в момент времени.
Для всей программы, был один [Task](http://alexcrichton.com/futures-rs/futures/task/struct.Task.html), который следовал 
логическому "потоку исполнения", который обрабатывал каждую future и общее вычисление прогрессировало.

В кратце, `Task` это сущность, которая на самом деле уравляет высокоуровневыми вызовами функции `poll`. Её основным 
методом занимающимся этим - является [run](http://alexcrichton.com/futures-rs/futures/task/struct.Task.html#method.run).
Внутренне, `Task` устроен таким образом, что, если 
[unpark](http://alexcrichton.com/futures-rs/futures/task/struct.TaskHandle.html#method.unpark) вызван из множества 
потоков - результирующие вызовы метода `poll` будут соответствующим образом скоординированны.

Задачи, сами по себе, как правило не создаются вручную, а производятся путём вызова функции 
[forget](http://alexcrichton.com/futures-rs/futures/trait.Future.html#method.forget).
Эта функция типажа [Future](http://alexcrichton.com/futures-rs/futures/trait.Future.html) создаёт новую 
[Task](http://alexcrichton.com/futures-rs/futures/task/struct.Task.html) и после запрашивает её запуск future, передавая
всю цепочку скомбинированных futures, в виде последовательности.

В продуманной реализации типажа `Task` кроется эффективность контейнера `futures`: когда `Task` создан, каждая из 
`Fututre` в цепочке вычислений объединяются в машину состояний и переносятся из стека в кучу. Это действией, является 
единственным, которое требует выделение памяти в контейнере `futures`. В результате, `Task` ведёт себя таким образом, 
как если бы вы написали машину состояний вручную, в качестве последовательности прямолинейных вычислений.

Концептуально, `Task` похож чем-то на потоки операционной системы. Там где потоки операционной системы вызывают функции, 
которые имеют доступ к стэку, который доступен посредством блокирующего ввода/вывода, асинхронное вычисление 
запускает отдельные futures, которые имеют доступ к `Task`, которое сохраняется в течении всего времени выполнения.

# Локальные данные задачи

В предыдущем разделе мы увидели как каждый отдельный future является частью большого асинхронного вычисления. Это 
означает, что futures приходят и уходят, но может возникнуть необходимость, чтобы у них был доступ к данным, которые 
живут на протяжении всего времени выполнения программы.

Futures требуют `'static`, так что у нас есть два варианта, для обмена данными между futures:

- если данные будут использованы только одним future в момент времени, то мы можем передавать владение данными между 
каждым future, которому потребуется доступ к данным;

- если доступ к данным должен быть паралельным, мы могли бы обернуть их в счётчик ссылок (`Arc / Rc`) или в худшем 
случае ещё и в мьютекс (`Arc<Mutex>`), если нам потребуется изменять их.

Оба эти решения являются относительно тяжеловесными, так давате посмотрим сможем ли мы сделать лучше.

В разделе `Task` и `Future` мы увидели, как асинхронные вычисления имеют доступ к `Task` на всём протяжении его жизни, 
и из сигнатуры метода `poll` было видно, что это изменяемый доступ к этой задаче. API `Task` использует это и позволяет 
вам хранить данные внутри `Task`.

Данные ассоциированные с `Task` с помощью функции 
[TaskData::new](http://alexcrichton.com/futures-rs/futures/task/struct.TaskData.html#method.new) возвращают хэндл 
[TaskData](http://alexcrichton.com/futures-rs/futures/task/struct.TaskData.html). Этот хэндл может быть клонирован 
независимо от исходных данных. Для доступа к данным после, вы можете использовать метод 
[with](http://alexcrichton.com/futures-rs/futures/task/struct.TaskData.html#method.with).

# Данные цикла событий

Теперь мы увидели как можно хранить данные в `Task` с помощью `TaskData`, но данные иногда не реализуют типаж `Send`.
Для этого случая, контейнер [tokio-core](https://github.com/tokio-rs/tokio-core) предоставляет аналогичную абстракцию - 
[LoopData](https://tokio-rs.github.io/tokio-core/tokio_core/struct.LoopData.html).

[LoopData](https://tokio-rs.github.io/tokio-core/tokio_core/struct.LoopData.html) аналогична 
[TaskData](http://alexcrichton.com/futures-rs/futures/task/struct.TaskData.html), где обработчик данных передаётся 
циклу событий. Ключевым свойством [LoopData](https://tokio-rs.github.io/tokio-core/tokio_core/struct.LoopData.html) 
является, то, что он реализует типаж `Send` независимо от того, какие данные мы захотим хранить в цикле событий.

Одним из ключевых методов типажа `Future` является `forget`, который требует future реализующий типаж `Send`. Это не 
всегда возможно для future, но `LoopData<F: Future>` реализует `Send` и типаж `Future` реализован напрямую для 
`LoopData<F>`. Это означает, что если future не реализует типаж `Send`, он может просто "превратиться" в реализующий
`Send` "прикрепляя" его в цикл событий предварительно обернув в `LoopData`.

Получить данные при помощи `LoopData` немного проще, чем с помощью `TaskData`, так как вам не нужно получать данные из 
задачи. Вместо этого вы можете получить данные просто при помощи методов 
[get](https://tokio-rs.github.io/tokio-core/tokio_core/struct.LoopData.html#method.get) или 
[get_mut](https://tokio-rs.github.io/tokio-core/tokio_core/struct.LoopData.html#method.get_mut). Оба эти метода 
возвращают `Option`, где `None` будет возвращён, если вы не в цикле событий.

В случае, если был возвращён `None`, future может вернуться в цикл событий для того чтобы продолжить выполнение.
Для того, чтобы гарантировать такое поведение,
[executor](https://tokio-rs.github.io/tokio-core/tokio_core/struct.LoopData.html#method.executor) ассоциирован с 
данными, которые могут быть получены и переданы в функцию 
[Task::pol_on](http://alexcrichton.com/futures-rs/futures/task/fn.poll_on.html).
Этот запрос, требующий чтобы задача опрашивалась сама по указанному исполнителю, который в данном случае будет 
выполнять запрос на опрос цикла событий, где данные могут быть доступны.

`LoopData` может быть создана с помощью двух методов:

- если вы получили хэндл [цикла событий](https://tokio-rs.github.io/tokio-core/tokio_core/struct.Loop.html), тогда 
вы можете вызвать метод 
[Loop::add_loop_data](https://tokio-rs.github.io/tokio-core/tokio_core/struct.Loop.html#method.add_loop_data). 
Это позволит вставлять данные напрямую и вернуть их хэндл сразу;

- если вы имеете [LoopHandle](https://tokio-rs.github.io/tokio-core/tokio_core/struct.LoopHandle.html), тогда вы можете 
вызвать метод 
[LoopHandle::add_loop_data](https://tokio-rs.github.io/tokio-core/tokio_core/struct.LoopHandle.html#method.add_loop_data).
В отличии от 
[Loop::add_loop_data](https://tokio-rs.github.io/tokio-core/tokio_core/struct.Loop.html#method.add_loop_data), он
требует замыкания, которое будет использовано для передачи и создания соответствующих данных. Вторым отличием является, 
тип возвращаемого значение, этот метод вернёт future, который вернёт значение типа 
[LoopData](`https://tokio-rs.github.io/tokio-core/tokio_core/struct.LoopData.html`).

Локальные данные задачи и данные цикла событий обеспечивают возможность для futures, лёгким упрвлением разделяемым 
состоянием, для отправляемых и не-отправляемых данных.