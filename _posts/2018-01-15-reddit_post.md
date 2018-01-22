---
layout: post
categories: размышления
title: "Rust: Назад к корням"
author: "0b_0101_001_1010"
original: https://www.reddit.com/r/rust/comments/7p6n90/rust2018_back_to_the_roots/
translator: bmusin
---

Мне приходит в голову множество разных целей для Rust в текущем 2018 году,
к слову, 2017 год прошел для меня очень быстро, так что я задался следующим
вопросом: если бы я мог выбрать одну-единственную цель для Rust в 2018 году,
то что бы я выбрал?

Я буду пристрастен, и вот мое мнение:

**2018 должен стать последним годом,когда приходится начинать писать новый
проект на C или C++**

<!--cut-->

Я системный программист ([HPC][hpc]) и сейчас, если мне придется выбрать для
работы язык программирования, то я могу выбирать лишь между C и C++. Rust
недостаточно хорош для меня, пусть я и использую его каждый день для всех
мелких проектов и прототипов.

Почему именно эта цель, а не какая-либо другая? Действительно, Rust хорошо
подходит для многих задач, которые лежат вне плоскости системного
рограммирования. Однако это очень широкая область, где уже и так имеется
довольно большое количество других ЯП, и так как они заточены под разные
задачи - некоторые, например, используют GC - то для некоторых специфических
задач они будут подходить лучше чем Rust.

С другой стороны, область системных ЯП достаточно узка и в ней имеются только
два закрепившихся родственных языка: C и C++. Сообщества, которые они
образуют, огромны (миллионы разработчиков), и эти программисты хотят, чтобы
на Rust'е можно было успешно решать те же задачи, которые они решают,
используя два вышеупомянутых ЯП.

Это здорово, что язык позволяет безопасно работать с памятью без GC, но для
C и C++ разработчиков использование Rust до сих вынуждает идти на некоторые
компромиссы. Так что 2018 год должен быть годом безопасной работы с памятью
без компромиссов: чтобы в 2019 году никто из тех, кто профессионально
занимается написанием `unsafe` кода не мог утверждать: "Я не могу
использовать Rust из-за X" и в то же время быть правым. У нас уже имеется
безопасный язык, в этом году мы должны провести такую работу, чтобы те, кому
нужна такая безопасность, не имели оправдания не использовать Rust. Написание
нового низкоуровневого проекта в 2019 году на С или C++ должно заставлять
людей удивленно поднимать брови и никак иначе.

Для того чтобы достичь этой цели, мы должны выяснить какие области системного
программирования (обработка финансовых транзакций, вычисления на
суперкомпьютерах, написание драйверов устройств, программирование ядер ОС,
программирование для встраиваемых систем, разработка игр, системы
автоматизированного проектирования (CAD), браузеры, компиляторы, и т. д.) имеют
проблемы, оценить их и устранить, чтобы сделать Rust наиболее подходящим
языком для этих областей.

Мы определенно должны параллельно улучшать Rust для использования в
WebAssembly, для написания скриптов, веб-разработки и других областей. Однако,
если бы мне пришлось выбрать одну главную цель для развития в этом году, то я
бы выбрал область системного программирования.

P.S: Я не хочу делать главным фокусом этой заметки какие-либо определенные
возможности языка. Есть много возможностей языка, работа над которыми уже
идет, но которые до сих пор находятся в незавершенном состоянии или нестабильны.

Относящиеся к языку:
- [модель][mm] памяти (C/C++)
- использование ассемблерных вставок в коде
- константные generic'и
- макросы 2.0
- поддержка асинхронного программирования (async/await)
- alloca (С)
- массивы с размером задаваемым во время выполнения (VLA)(С)

Относящиеся к библиотекам:
- потоковые итераторы (С++)
- использование SIMD инструкций (С/C++)
- встроенные функции компилятора (intrinsics)
- аллокаторы памяти (C++)
- обработка положений нехватки памяти (OOM) (С++)

Инструментарий:
- выявление неопределенного поведения (UB): 100% выявление UB во время
выполнения
- определение покрытия кода тестами в cargo
- IDE (C/C++): автодополнение, переход к определению, переименовывание,
  рефакторинг, форматирование кода - все это должно просто работать "из коробки"
- Сargo: улучшение работы в корпоративной среде
  (использование сквозь ssh-туннели, внутренние зеркала),
  объединение xargo/cross в единый cargo
- Платформы: поддержка компиляции в С код
  или использование GCC в качестве backend'а, поддержка CUDA
- улучшение совместимости Rust с C++ кодом: шаблоны, концепты и модули

Замечу, что каждой их этих проблем было уделено много часов работы в
Rust-сообществе. Я не упомянул ABI-совместимость, так как этому было уделено
сравнительно мало внимания.

В частности, работа над моделью памяти и неопределенным поведением - это то,
что может выгодно отличить Rust от C и C++, которые также имеют свои модели
памяти, но не имеют способа выявлять неопределенное поведение (UB). Можно даже
сказать, что отсутствие модели памяти делает язык гораздо менее безопасным и
предсказуемым чем C и C++, на мой взгляд.

[hpc]: https://en.wikipedia.org/wiki/High-performance_computing "HPC"
[mm]: https://www.reddit.com/r/rust/comments/7p6n90/rust2018_back_to_the_roots/dseyded/