---
title: "Futures нулевой стоимости в Rust"
author: Aaron Turon (перевёл Сергей Ефремов)
categories: обучение
excerpt: >
    Новые возможности Rust по использованию Futures.
---

Это перевод [статьи](http://aturon.github.io/blog/2016/08/11/futures/).
    
   
Одним из основных пробелов в экосистеме Rust был рассказ о быстром и
продуктивном `асинхронном вводе/выводе`. У нас есть прочный фундамент из
библиотеки [mio](http://github.com/carllerche/mio), но она очень низкоуровневая:
приходится вручную создавать конечные автоматы и жонглировать обратными
вызовами.

Нам бы хотелось чего-нибудь более высокоуровнего, с лучшей эргономикой, но чтобы
оно обладало хорошей `компонуемостью`, поддерживая экосистему асинхронных
абстракций, работающих вместе. Звучит очень знакомо: ту же цель преследовало
внедрение `futures` (или promises) во [многие языки](https://en.wikipedia.org/wiki/Futures_and_promises#List_of_implementations), поддерживающие синтаксический
сахар ввиде `async/await` на вершине.

Основным принципом Rust является возможность строить [абстракции с нулевойстоимостью](https://blog.rust-lang.org/2015/05/11/traits.html), что приводит нас
к дополнительной цели нашего рассказа о async I/O: в идеале абстракции как
futures должны компилироваться в что-то эквивалентное коду в виде конечных-
автоматов-и-жонглированием-обратными-вызовам, который мы сегодня пишем (без
дополнительных накладных расходов во времени исполнения).

Последние несколько месяцев, Alex Crichton и Я разрабатывали [библиотеку futures
нулевой стоимости](https://github.com/alexcrichton/futures-rs) для Rust, ту,
которая, мы считаем, позволит достичь этих целей. (Спасибо Carl Lerche, Yehuda
Katz, и Nicholas Matsakis за понимание на все пути.)

Сегодня мы рады начать серию статей о новой библиотеке. В этом посте
рассказываются самые яркие моменты, ключевые идеи и несколько предварительных
тестов. Дальнейшие посты покажут, как возможности Rust используются в
проектировании этих абстракций с нулевой стоимостью. Также вас уже ждет
[туториал](https://github.com/alexcrichton/futures-rs/blob/master/TUTORIAL.md).

#### Почему async I/O?

Прежде, чем копать futures, полезно будет рассказать немного о прошлом.

Начнем с маленького кусочка I/O, который вы хотели бы выполнить: чтение
определенного количества байт из сокета. Rust предоставляет функцию
[read_exact](https://static.rust-
lang.org/doc/master/std/io/trait.Read.html#method.read_exact) для этого:

```rust
// reads 256 bytes into `my_vec`
socket.read_exact(&mut my_vec[..256]);
```

Бытрый вопрос: что происходит, если у нас еще недостаточно байт получено от сокета?

Для сегодняшнего Rust ответ такой: текущий поток блокируется, засыпая пока не
будут получены еще байты. Но так было не всегда.

Давным давно в Rust была реализована модель `зеленых потоков`, не такая как в
Go. Вы могли завести огромное количество легковестных `заданий`, которые потом
были распределены по реальным потокам ОС (иногда такая система называется `M:N
threading`). В моделе зеленых потоков функция `read_exact` заблокирует текущее
`задание`, но не поток ОС; вместо этого, планировщик заданий переключится на
другое задание. Это великолепно, можно использовать огромное количество заданий,
большинство из которых блокировано, используя небольшое количество потоков ОС.

Проблема в том, что модель зеленых потоков [шла в
разрез](https://mail.mozilla.org/pipermail/rust-dev/2013-November/006314.html)
амбициям Rust по полной замене Си, без какой-либо дополнительно навязанной
системы выполнения или увеличения цены FFI: мы так и не нашли стратегию их
реализации, которая бы не накладывала дополнительных серьезных глобальных
расходов. Вы можете почитать больше [в RFC, в котором были удалены зеленые
потоки](https://github.com/aturon/rfcs/blob/remove-runtime/active/0000-remove-
runtime.md).

Итак, если мы хотим держать большое число одновременных подключений, многие из
которых ждут I/O, но при этом держать число потоков ОС на минимуме, что еще мы
можем сделать?

Асинхронный I/O - вот ответ, на самом деле он также используется и для
реализации  зеленых потоков.

В двух словах, благодаря async I/O вы можете `попытаться` выполнить операцию I/O
без блокировки. Если она не может мгновенно выполниться, можно попробовать через
какое-то время. Для того, чтобы это работало, ОС предоставляет различные
инструменты, как [epoll](https://en.wikipedia.org/wiki/Epoll), позволяющие
запросить, какие объекты из огромного списка I/O объектов `готовы` к чтению или
записи - по существу это API, которое предоставляет
[mio](http://github.com/carllerche/mio).

Проблема в том, что надо выполнить много болезненной работы по слежению за
списком интересных вам I/O событий, и передать эти события правильным обратным
вызовам (не говоря уже о программировании чисто callback-driven способом). Это
одна из ключевых проблем, которую решают futures.</p>

#### Futures

Итак, `что` такое future?

По существу, future представляет собой значение, которое может быть еще не
готово. Обычно, future становится `законченным` (значение готово) после какого-
то произошедшего события где-то в другом месте. Мы рассматривали их со стороно
базового I/O, вы можете использовать future для представления огромного числа
различных событий, например:


- *Запрос к БД*, который выполняется в пуле потоков. Если запрос выполнился,
future станет законченным, а в его значении будет результат запроса.
- *Выполнение RPC* на сервере. Если сервер ответил, future станет законченным, а
в его значении будет ответ сервера.
- *Таймаут*. Если время вышло, future станет законченным, а его значением будет 
() (единичное значение в Rust).
- *Долго выполняющееся CPU-затратное задание*, выполняющееся в пуле потоков.
Когда задание заканчивается, future станет законченным, а его значением будет 
значение задания.
- *Чтение байт из сокета*. Если байты готовы, future станет законченным - и в 
зависимости от стратегии буферизации, байты могут быть получены напрямую или 
записаны в дополнительный уже существующий буфер.

<p>And so on. The point is that futures are applicable to asynchronous
events of all shapes and sizes. The asynchrony is reflected in the fact that you
get a <em>future</em> right away, without blocking, even though the <em>value</em> the future
represents will become ready only at some unknown time in the&hellip; future.</p>

<p>In Rust, we represent futures as a
<a href="http://alexcrichton.com/futures-rs/futures/trait.Future.html">trait</a> (i.e., an
interface), roughly:</p>
<div class="highlight"><pre><code class="language-rust" data-lang="rust"><span class="k">trait</span> <span class="n">Future</span> <span class="p">{</span>
    <span class="k">type</span> <span class="n">Item</span><span class="p">;</span>
    <span class="c1">// ... lots more elided ...</span>
<span class="p">}</span>
</code></pre></div>
<p>The <code>Item</code> type says what kind of value the future will yield once it&rsquo;s complete.</p>

<p>Going back to our earlier list of examples, we can write several functions
producing different futures (using
<a href="https://github.com/rust-lang/rfcs/pull/1522"><code>impl</code> syntax</a>):</p>
<div class="highlight"><pre><code class="language-rust" data-lang="rust"><span class="c1">// Lookup a row in a table by the given id, yielding the row when finished</span>
<span class="k">fn</span> <span class="n">get_row</span><span class="p">(</span><span class="n">id</span><span class="o">:</span> <span class="kt">i32</span><span class="p">)</span> <span class="o">-&gt;</span> <span class="k">impl</span> <span class="n">Future</span><span class="o">&lt;</span><span class="n">Item</span> <span class="o">=</span> <span class="n">Row</span><span class="o">&gt;</span><span class="p">;</span>

<span class="c1">// Makes an RPC call that will yield an i32</span>
<span class="k">fn</span> <span class="n">id_rpc</span><span class="p">(</span><span class="n">server</span><span class="o">:</span> <span class="o">&amp;</span><span class="n">RpcServer</span><span class="p">)</span> <span class="o">-&gt;</span> <span class="k">impl</span> <span class="n">Future</span><span class="o">&lt;</span><span class="n">Item</span> <span class="o">=</span> <span class="kt">i32</span><span class="o">&gt;</span><span class="p">;</span>

<span class="c1">// Writes an entire string to a TcpStream, yielding back the stream when finished</span>
<span class="k">fn</span> <span class="n">write_string</span><span class="p">(</span><span class="n">socket</span><span class="o">:</span> <span class="n">TcpStream</span><span class="p">,</span> <span class="n">data</span><span class="o">:</span> <span class="n">String</span><span class="p">)</span> <span class="o">-&gt;</span> <span class="k">impl</span> <span class="n">Future</span><span class="o">&lt;</span><span class="n">Item</span> <span class="o">=</span> <span class="n">TcpStream</span><span class="o">&gt;</span><span class="p">;</span>
</code></pre></div>
<p>All of these functions will return their future <em>immediately</em>, whether or not
the event the future represents is complete; the functions are
non-blocking.</p>

<p>Things really start getting interesting with futures when you combine
them. There are endless ways of doing so, e.g.:</p>

<ul>
<li><p><a href="http://alexcrichton.com/futures-rs/futures/trait.Future.html#method.and_then"><strong>Sequential composition</strong></a>:
<code>f.and_then(|val| some_new_future(val))</code>. Gives you a future that executes the
future <code>f</code>, takes the <code>val</code> it produces to build another future
<code>some_new_future(val)</code>, and then executes that future.</p></li>
<li><p><a href="http://alexcrichton.com/futures-rs/futures/trait.Future.html#method.map"><strong>Mapping</strong></a>:
<code>f.map(|val| some_new_value(val))</code>. Gives you a future that
executes the future <code>f</code> and yields the result of <code>some_new_value(val)</code>.</p></li>
<li><p><a href="http://alexcrichton.com/futures-rs/futures/trait.Future.html#method.join"><strong>Joining</strong></a>:
<code>f.join(g)</code>. Gives you a future that executes the futures <code>f</code> and
<code>g</code> in parallel, and completes when <em>both</em> of them are complete, returning
both of their values.</p></li>
<li><p><a href="http://alexcrichton.com/futures-rs/futures/trait.Future.html#method.select"><strong>Selecting</strong></a>:
<code>f.select(g)</code>. Gives you a future that executes the futures <code>f</code>
and <code>g</code> in parallel, and completes when <em>one of</em> them is complete, returning
its value and the other future. (Want to add a timeout to any future? Just do
a <code>select</code> of that future and a timeout future!)</p></li>
</ul>

<p>As a simple example using the futures above, we might write something like:</p>
<div class="highlight"><pre><code class="language-rust" data-lang="rust"><span class="n">id_rpc</span><span class="p">(</span><span class="o">&amp;</span><span class="n">my_server</span><span class="p">).</span><span class="n">and_then</span><span class="p">(</span><span class="o">|</span><span class="n">id</span><span class="o">|</span> <span class="p">{</span>
    <span class="n">get_row</span><span class="p">(</span><span class="n">id</span><span class="p">)</span>
<span class="p">}).</span><span class="n">map</span><span class="p">(</span><span class="o">|</span><span class="n">row</span><span class="o">|</span> <span class="p">{</span>
    <span class="n">json</span><span class="o">::</span><span class="n">encode</span><span class="p">(</span><span class="n">row</span><span class="p">)</span>
<span class="p">}).</span><span class="n">and_then</span><span class="p">(</span><span class="o">|</span><span class="n">encoded</span><span class="o">|</span> <span class="p">{</span>
    <span class="n">write_string</span><span class="p">(</span><span class="n">my_socket</span><span class="p">,</span> <span class="n">encoded</span><span class="p">)</span>
<span class="p">})</span>
</code></pre></div>
<blockquote>
<p>See
<a href="https://github.com/alexcrichton/futures-rs/blob/master/futures-minihttp/techempower2/src/main.rs">this code</a>
for a more fleshed out example.</p>
</blockquote>

<p>This is non-blocking code that moves through several states: first we do an RPC
call to acquire an ID; then we look up the corresponding row; then we encode it
to json; then we write it to a socket. <strong>Under the hood, this code will compile
down to an actual state machine which progresses via callbacks (with no
overhead)</strong>, but we get to write it in a style that&rsquo;s not far from simple
<em>blocking</em> code. (Rustaceans will note that this story is very similar to
<code>Iterator</code> in the standard library.)  Ergonomic, high-level code that compiles
to state-machine-and-callbacks: that&rsquo;s what we were after!</p>

<p>It&rsquo;s also worth considering that each of the futures being used here might come
from a different library. The futures abstraction allows them to all be combined
seamlessly together.</p>

<h2 id="streams">Streams</h2>

<p>But wait &ndash; there&rsquo;s more! As you keep pushing on the future &ldquo;combinators&rdquo;,
you&rsquo;re able to not just reach parity with simple blocking code, but to do things
that can be tricky or painful to write otherwise. To see an example, we&rsquo;ll need one
more concept: streams.</p>

<p>Futures are all about a <em>single</em> value that will eventually be produced, but
many event sources naturally produce a <em>stream</em> of values over time. For
example, incoming TCP connections or incoming requests on a socket are both
naturally streams.</p>

<p>The futures library includes a
<a href="http://alexcrichton.com/futures-rs/futures/stream/trait.Stream.html"><code>Stream</code> trait</a>
as well, which is very similar to futures, but set up to produce a sequence of
values over time. It has a set of combinators, some of which work with
futures. For example, if <code>s</code> is a stream, you can write:</p>
<div class="highlight"><pre><code class="language-rust" data-lang="rust"><span class="n">s</span><span class="p">.</span><span class="n">and_then</span><span class="p">(</span><span class="o">|</span><span class="n">val</span><span class="o">|</span> <span class="n">some_future</span><span class="p">(</span><span class="n">val</span><span class="p">))</span>
</code></pre></div>
<p>This code will give you a new stream that works by first pulling a value <code>val</code>
from <code>s</code>, then computing <code>some_future(val)</code> from it, then executing that future
and yielding its value &ndash; then doing it all over again to produce the next value
in the stream.</p>

<p>Let&rsquo;s see a real example:</p>
<div class="highlight"><pre><code class="language-rust" data-lang="rust"><span class="c1">// Given an `input` I/O object create a stream of requests</span>
<span class="kd">let</span> <span class="n">requests</span> <span class="o">=</span> <span class="n">ParseStream</span><span class="o">::</span><span class="n">new</span><span class="p">(</span><span class="n">input</span><span class="p">);</span>

<span class="c1">// For each request, run our service&#39;s `process` function to handle the request</span>
<span class="c1">// and generate a response</span>
<span class="kd">let</span> <span class="n">responses</span> <span class="o">=</span> <span class="n">requests</span><span class="p">.</span><span class="n">and_then</span><span class="p">(</span><span class="o">|</span><span class="n">req</span><span class="o">|</span> <span class="n">service</span><span class="p">.</span><span class="n">process</span><span class="p">(</span><span class="n">req</span><span class="p">));</span>

<span class="c1">// Create a new future that&#39;ll write out each response to an `output` I/O object</span>
<span class="n">StreamWriter</span><span class="o">::</span><span class="n">new</span><span class="p">(</span><span class="n">responses</span><span class="p">,</span> <span class="n">output</span><span class="p">)</span>
</code></pre></div>
<p>Here, we&rsquo;ve written the core of a simple server by operating on streams. It&rsquo;s
not rocket science, but it is a bit exciting to be manipulating values like
<code>responses</code> that represent the entirety of what the server is producing.</p>

<p>Let&rsquo;s make things more interesting. Assume the protocol is pipelined, i.e., that
the client can send additional requests on the socket before hearing back from
the ones being processed. We want to actually process the requests sequentially,
but there&rsquo;s an opportunity for some parallelism here: we could read <em>and parse</em>
a few requests ahead, while the current request is being processed. Doing so is
as easy as inserting one more combinator in the right place:</p>
<div class="highlight"><pre><code class="language-rust" data-lang="rust"><span class="kd">let</span> <span class="n">requests</span> <span class="o">=</span> <span class="n">ParseStream</span><span class="o">::</span><span class="n">new</span><span class="p">(</span><span class="n">input</span><span class="p">);</span>
<span class="kd">let</span> <span class="n">responses</span> <span class="o">=</span> <span class="n">requests</span><span class="p">.</span><span class="n">map</span><span class="p">(</span><span class="o">|</span><span class="n">req</span><span class="o">|</span> <span class="n">service</span><span class="p">.</span><span class="n">process</span><span class="p">(</span><span class="n">req</span><span class="p">)).</span><span class="n">buffered</span><span class="p">(</span><span class="mi">32</span><span class="p">);</span> <span class="c1">// &lt;--</span>
<span class="n">StreamWriter</span><span class="o">::</span><span class="n">new</span><span class="p">(</span><span class="n">responsesm</span><span class="p">,</span> <span class="n">output</span><span class="p">)</span>
</code></pre></div>
<p>The
<a href="http://alexcrichton.com/futures-rs/futures/stream/trait.Stream.html#method.buffered"><code>buffered</code> combinator</a>
takes a stream of <em>futures</em> and buffers it by some fixed amount. Buffering the
stream means that it will eagerly pull out more than the requested number of
items, and stash the resulting futures in a buffer for later processing. In this
case, that means that we will read and parse up to 32 extra requests in parallel,
while running <code>process</code> on the current one.</p>

<p>These are relatively simple examples of using futures and streams, but hopefully
they convey some sense of how the combinators can empower you to do very
high-level async programming.</p>

<h2 id="zero-cost">Zero cost?</h2>

<p>I&rsquo;ve claimed a few times that our futures library provides a zero-cost
abstraction, in that it compiles to something very close to the state machine
code you&rsquo;d write by hand. To make that a bit more concrete:</p>

<ul>
<li><p>None of the future combinators impose any allocation. When we do things like
chain uses of <code>and_then</code>, not only are we not allocating, we are in fact
building up a big <code>enum</code> that represents the state machine. (There is one
allocation needed per &ldquo;task&rdquo;, which usually works out to one per connection.)</p></li>
<li><p>When an event arrives, only one dynamic dispatch is required.</p></li>
<li><p>There are essentially no imposed synchronization costs; if you want to
associate data that lives on your event loop and access it in a
single-threaded way from futures, we give you the tools to do so.</p></li>
</ul>

<p>And so on. Later blog posts will get into the details of these claims and show
how we leverage Rust to get to zero cost.</p>

<p>But the proof is in the pudding. We wrote a simple HTTP server framework,
<a href="https://github.com/alexcrichton/futures-rs/tree/master/futures-minihttp">minihttp</a>,
which supports pipelining and TLS. <strong>This server uses futures at every level of
its implementation, from reading bytes off a socket to processing streams of
requests</strong>. Besides being a pleasant way to write the server, this provides a
pretty strong stress test for the overhead of the futures abstraction.</p>

<p>To get a basic assessment of that overhead, we then implemented the
<a href="https://www.techempower.com/benchmarks/#section=data-r12&amp;hw=peak&amp;test=plaintext">TechEmpower &ldquo;plaintext&rdquo; benchmark</a>. This
microbenchmark tests a &ldquo;hello world&rdquo; HTTP server by throwing a huge number of
concurrent and pipelined requests at it. Since the &ldquo;work&rdquo; that the server is
doing to process the requests is trivial, the performance is largely a
reflection of the basic overhead of the server framework (and in our case, the
futures framework).</p>

<p>TechEmpower is used to compare a very large number of web frameworks across many
different languages. We
<a href="https://github.com/alexcrichton/futures-rs/blob/master/futures-minihttp/README.md">compared</a>
minihttp to a few of the top contenders:</p>

<ul>
<li><p><a href="https://github.com/TechEmpower/FrameworkBenchmarks/tree/master/frameworks/Java/rapidoid">rapidoid</a>,
a Java framework, which was the top performer in the last round of official benchmarks.</p></li>
<li><p><a href="https://github.com/TechEmpower/FrameworkBenchmarks/tree/master/frameworks/Go/go-std">Go</a>,
an implementation that uses Go&rsquo;s standard library&rsquo;s HTTP support.</p></li>
<li><p><a href="https://github.com/TechEmpower/FrameworkBenchmarks/tree/master/frameworks/Go/fasthttp">fasthttp</a>,
a competitor to Go&rsquo;s standard library.</p></li>
<li><p><a href="https://github.com/TechEmpower/FrameworkBenchmarks/tree/master/frameworks/JavaScript/nodejs">node.js</a>.</p></li>
</ul>

<p>Here are the results, in number of &ldquo;Hello world!&quot;s served per second on an 8
core Linux machine:</p>

<p><img src="/blog/public/bench-pipelined.png"></p>

<p>It seems safe to say that futures are not imposing significant overhead.</p>

<p><strong>Update</strong>: to provide some extra evidence, we&rsquo;ve
  <a href="https://github.com/alexcrichton/futures-rs/blob/master/futures-minihttp/README.md">added a comparison</a>
  of minihttp against a directly-coded state machine version in Rust (see &quot;raw
  mio&rdquo; in the link). The two are within 0.3% of each other.</p>

<h2 id="the-future">The future</h2>

<p>Thus concludes our whirlwind introduction to zero-cost futures in Rust. We&rsquo;ll
see more details about the design in the posts to come.</p>

<p>At this point, the library is quite usable, and pretty thoroughly documented; it
comes with a
<a href="https://github.com/alexcrichton/futures-rs/blob/master/TUTORIAL.md">tutorial</a>
and plenty of examples, including:</p>

<ul>
<li>a simple <a href="https://github.com/alexcrichton/futures-rs/blob/master/futures-mio/src/bin/echo.rs">TCP echo server</a>;</li>
<li>an efficient
<a href="https://github.com/alexcrichton/futures-rs/blob/master/futures-socks5/src/main.rs">SOCKSv5 proxy server</a>;</li>
<li><code>minihttp</code>, a highly-efficient
<a href="https://github.com/alexcrichton/futures-rs/tree/master/futures-minihttp">HTTP server</a>
that supports TLS and uses
<a href="https://crates.io/crates/httparse">Hyper&rsquo;s parser</a>;</li>
<li>an example
<a href="https://github.com/alexcrichton/futures-rs/tree/master/futures-minihttp/tls-example">use of minihttp</a>
for TLS connections,</li>
</ul>

<p>as well as a variety of integrations, e.g. a futures-based interface to
<a href="http://alexcrichton.com/futures-rs/futures_curl">curl</a>. We&rsquo;re actively working
with several people in the Rust community to integrate with their work; if
you&rsquo;re interested, please reach out to Alex or myself!</p>

<p>If you want to do low-level I/O programming with futures, you can use
<a href="http://alexcrichton.com/futures-rs/futures_mio">futures-mio</a> to do so on top of
mio. We think this is an exciting direction to take async I/O programming in
general in Rust, and follow up posts will go into more detail on the mechanics.</p>

<p>Alternatively, if you just want to speak HTTP, you can work on top of
<a href="https://github.com/alexcrichton/futures-rs/tree/master/futures-minihttp">minihttp</a>
by providing a <em>service</em>: a function that takes an HTTP request, and returns a
<em>future</em> of an HTTP response. This kind of RPC/service abstraction opens the
door to writing a lot of reusable &ldquo;middleware&rdquo; for servers, and has gotten a lot
of traction in Twitter&rsquo;s <a href="https://twitter.github.io/finagle/">Finagle</a> library
for Scala; it&rsquo;s also being used in Facebook&rsquo;s
<a href="https://github.com/facebook/wangle">Wangle</a> library. In the Rust world, there&rsquo;s
already a library called
<a href="https://medium.com/@carllerche/announcing-tokio-df6bb4ddb34#.g9ugbqg71">Tokio</a>
in the works that builds a general service abstraction on our futures library,
and could serve a role similar to Finagle.</p>

<p>There&rsquo;s an enormous amount of work ahead:</p>

<ul>
<li><p>First off, we&rsquo;re eager to hear feedback on the core future and stream
abstractions, and there are some specific design details for some combinators
we&rsquo;re unsure about.</p></li>
<li><p>Second, while we&rsquo;ve built a number of future abstractions around basic I/O
concepts, there&rsquo;s definitely more room to explore, and we&rsquo;d appreciate help
exploring it.</p></li>
<li><p>More broadly, there are endless futures &ldquo;bindings&rdquo; for various libraries (both
in C and in Rust) to write; if you&rsquo;ve got a library you&rsquo;d like futures bindings
for, we&rsquo;re excited to help!</p></li>
<li><p>Thinking more long term, an obvious eventual step would be to explore
<code>async</code>/<code>await</code> notation on top of futures, perhaps in the same way as proposed
in <a href="https://tc39.github.io/ecmascript-asyncawait/">Javascript</a>. But we want to
gain more experience using futures directly as a library, first, before
considering such a step.</p></li>
</ul>

<p>Whatever your interests might be, we&rsquo;d love to hear from you &ndash; we&rsquo;re <code>acrichto</code>
and <code>aturon</code> on Rust&rsquo;s
<a href="https://www.rust-lang.org/en-US/community.html">IRC channels</a>. Come say hi!</p>

</article>


<aside class="related">
  <h2>Related Posts</h2>
  <ul class="related-posts">
    
      <li>
        <h3>
          <a href="/blog/2016/07/27/rust-platform/">
            The Rust Platform
            <small><time datetime="2016-07-27T00:00:00-07:00">27 Jul 2016</time></small>
          </a>
        </h3>
      </li>
    
      <li>
        <h3>
          <a href="/blog/2016/07/05/rfc-refinement/">
            Refining Rust's RFCs
            <small><time datetime="2016-07-05T00:00:00-07:00">05 Jul 2016</time></small>
          </a>
        </h3>
      </li>
    
      <li>
        <h3>
          <a href="/blog/2015/09/28/impl-trait/">
            Resurrecting impl Trait
            <small><time datetime="2015-09-28T00:00:00-07:00">28 Sep 2015</time></small>
          </a>
        </h3>
      </li>
    
  </ul>
</aside>


      </main>

      <footer class="footer">
        <small>
          &copy; <time datetime="2016-08-11T10:34:52-07:00">2016</time>. All rights reserved.
        </small>
      </footer>
    </div>

  </body>
</html>
