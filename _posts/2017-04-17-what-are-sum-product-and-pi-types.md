---
title: "Что такое тип-сумма, тип-произведение и тип-π?"
author: Manish Goregaokar
original: https://manishearth.github.io/blog/2017/03/04/what-are-sum-product-and-pi-types/
translator: Сергей Веселков
categories: обучение
math: true
---

Вы часто слышите, как люди говорят "У языка X[^1] есть тип-сумма", или "Я хотел бы, что бы в языке X были тип-суммы"[^2],
или "Тип-суммы - это круто".

Так же, как и фески или галстуки-бабочки, тип-суммы - это действительно круто.

img

Сейчас также встречаються люди, которые спрашивают о "тип-π" из-за этого [RFC][pi-types-rfc].

Но что такое "тип-сумма"? Почему это так назывваеться? И что, чёрт побери, такое "тип-π"?!

Прежде чем начать, стоит отметить, что пока мы будем рассматривать некоторую часть теории типов для объяснения терминов "сумма" и
"произведение", вам не нужно понимать эти термины для использования этих вещей! Слишком часто у людей возникают проблемы с пониманием
относительно простых понятий в языках, из-за того что они имеют сложные названия с запутаными математическими обоснованиями[^3].

# Что же такое тип-сумма? (версия без теории типов)

По сути "тип-сумма" это обычный тип "или". Давайте сначала рассмотрим структуры.

```
struct Foo {
    x: bool,
    y: String,
}
```

`Foo` состоит из `bool` И `String`. Вам нужно по одному для каждого экземпляра. Это и есть тип "и", или "тип-произведение"
(мы разберём этот термин позже).

Чем же тогда будет тип "или"? Это тип, значение которого может быть либо `bool`, либо `String`.
В C++ вы можете достичь этого с помощью объединений:

```
union Foo {
    bool x;
    string y;
}

foo.x = true; // присваиваем логический тип
foo.y = "blah"; // присваиваем строковый тип
```

Однако это не совсем правильно, поскольку экземпляр не хранит информацию о том, какого он типа.
Вы можете записать туда `false` и при обращении будет неизвестно, хранится ли там пустая строка или логическое `false`.

В C++ для решения этой проблемы есть шаблон проектирования "меченое объединение" (или "дизъюнктное объединение").

```
union FooUnion {
    bool x;
    string y;
}

enum FooTag {
    BOOL, STRING
}

struct Foo {
    FooUnion data;
    FooTag tag;
}

// присваиваем логический тип
foo.data.x = true;
foo.tag = BOOL;

// присваиваем строковый тип
foo.data.y = "blah";
foo.tag = STRING;
```

В данном примере вам нужно самостоятельно присвоить тэг при присвавании значения. В C++ также есть `std::variant`
(или `boost::variant`), который реализуют данный шаблон с более удобным API.

Техническое название типа "или" - тип-сумма. Часть других языков имеют встроенную поддержку тип-суммы.

В Rust есть встроенная поддержка тип-сумм, их называют "перечисления". Это более обощённая версия перечислений по сравнению с другими языками.

```
enum Foo {
    Str(String),
    Bool(bool)
}

let foo = Foo::Bool(true);

// "сопоставление с образцом"
match foo {
    Str(s) => /* делаем что-то со строкой `s` */,
    Bool(b) => /* делаем что-то с логической `b` */,
}
```

В Swift тип-суммы так же называются перечислениями

```
enum Foo {
    case str(String)
    case boolean(bool)
}

let foo = Foo.boolean(true);
switch foo {
    case .str(let s):
        // делаем что-то со строкой `s`
    case .boolean(let b):
        // делаем что-то с логической `b`
}
```

В Go вы можете представить тип-сумму в виде интерфейсов. Typescript имеют встроенную поддержку объединений с
возможностью проверки типов, но вам нужно добавить тег (как и в C++) для того чтобы сопосталять их.

В Haskell конечно же есть тип-суммы:

```
data Foo = B Bool | S String

-- определяем функцию
doThing :: Foo -> SomeReturnType
doThing (B b) = -- делаем что-то с логической b
doThing (S s) = -- делаем что-то со строкой s

-- вызываем функцию
doThing (S "blah")
doThing (B True)
```

Одна из самых распростарннёных вещей, которая реализуеца в языках с поддержкой тип-сумм, это выражение типа
с возможным отсутствием значения через тип-сумму:

```
// `Option` является либо "чем-то" содержащим тип, либо "ничем"
enum Option<T> {
    Some(T),
    None
}

let x = Some("привет");
match x {
    Some(s) => println!("{}", s),
    None => println!("для вас нет строки"),
}
```

У большинства таких языков есть "сопоставление с образцом", которое работает как `switch` на стероидах. Оно позваоляет вам сопоставлять
и обрабатывать все возможные вещи, тип-сумма являеться одной из них. Обычно сопоставление являеться "исчерпывающим". Это означает, что
вы обязаны обработать все возможные варианты. Например, если в Rust вы удалите ветку с `None`, то программа не скомпилируется. В итоге
вам нужно как-то обработать вариант с отсутствием значения.

В целом тип-суммы довольно изящный и мощный инструмент. Языки со встроенной поддержкой тип-сумм стараются активно их использовать.
Фактически они используют их так же часто, как и структуры.

# Почему мы назваем это тип-сумма?

[Драконы][dragons] (теория типов) здесь.

Давайте вернёмся немного назад и разберёмся, что это за тип.

На самом деле этот тип являеться ограничением допустимых значений. У него так же могут быть методы и всякая всячина к нему привязаная,
но сейчас это не так важно.

Другими словами этот тип похож[^4] на [множество][set]. Логический тип - это множество \`{tt"true",tt"false"}\`.
8-битное беззнаковое целое (`u8` в Rust) - это множество \`{0,1,2,3,.... 254,255}\`. Строка - это множество с бесконечным количеством элементов,
включающим в себя все возможные строки[^5].

А что на счёт структуры? Структура с двумя полями включает в себя все возможные комбинации элементов из множеств этих полей.

```
struct Foo {
    x: bool,
    y: u8,
}
```

Множество возможных значений `Foo`

\`{(tt"x", tt"y"): tt"x" in tt"bool", tt"y" in tt"u8"}\`

(Читается как "Множество всех \`(tt"x", tt"y")\` где \`tt"x"\` принадлежит \`tt"bool"\` и \`tt"y"\` принадлежит \`tt"u8"\`")

Это называеться декартовым произведением и обычно записывается в виде \`tt"Foo" = tt"bool" xx tt"u8"\`. Простой способ представить
структуру в виде произведения - это посчитать её возможные значения. Например, количество возможных значений `Foo` - это количество
возможных значений `bool` (2) и количество возможных значений `u8` (256).

В общем случае структура будет "произведением" её типов между собой. Например

```
struct Bar {
    x: bool,
    y: u8,
    z: bool,
    w: String
}
```

будет \`tt"Bar" = tt"bool" xx tt"u8" xx tt"bool" xx tt"Sting"\`

Из-за этого структуры и называют "тип-произведение"[^6].

Вы, наверное, догадываетесь, что будет дальше - объединения в Rust/Swift называют "тип-суммами", поскольку они являютя
суммой двух множеств.

```
enum Foo {
    Bool(bool),
    Integer(u8),
}
```

это множество всех логических значений и всех 8-битных беззнаковых целых. Это сумма множеств: \`tt"Foo" = tt"bool" + tt"u8"\`.
Точнее, это дизъюнктное объединение - объединение при котором пересекающиеся элементы входных множеств сохраняют свою
уникальность.

Примером этого будет дизъюнктное объединение:

```
enum Bar {
    Bool1(bool),
    Bool2(bool),
    Integer(u8).
}
```

Утверждение \`tt"Bar" = tt"bool" + tt"bool" + tt"u8"\` неверно, поскольку \`tt"bool" + tt"bool" = tt"bool"\`
(обычное объединение множеств не сохраняет уникальность пересекающихся элементов).

Вместо этого, его нужно представить в виде:

\`tt"Bar" = tt"bool" + tt"otherbool" + tt"u8"\`

где \`tt"otherbool"\` это тоже множество \`{tt"true", tt"false"}\`, за исключением того, что эти элементы отличаются от тех,
которые в \`tt"bool"\`. Мы можем посмотреть на это как на

\`tt"otherbool" = {tt"true"_2, tt"false"_2}\`

таким образом

\`tt"bool" + tt"otherbool" = {tt"true", tt"false", tt"true"_2, tt"false"_2}\`

Для тип-суммы количесвто возможных значений - это сумма количества значений каждого из его компоненотв.

Так что в Rust/Swift объединения - это "тип-суммы".

You may often notice the terminology “algebraic datatypes” (ADT) being used, usually that’s just talking about sum and
product types together – a language with ADTs will have both.

In fact, you can even have exponential types! The notation \`A^{B}\` in set theory does mean something, it’s the set of all
possible mappings from \`B\` to \`A\`. The number of elements is \`N_{A}^{N_{B}}\`. So basically, the type of a function
(which is a mapping) is an “exponential” type. You can also view it as an iterated product type, a function from type `B` to `A`
is really a struct like this:

```
// the type
fn my_func(b: B) -> A;

// is conceptually (each possible my_func can be written as an instance of)

struct my_func {
    b1: A, // value for first element in B
    b2: A, // value for second element in B
    b3: A,
    // ...
}
```

given a value of the input `b`, the function will find the right field of `my_func` and return the mapping. Since a struct
is a product type, this is

\`tt"A"^{N_tt"B"} = tt"A" xx tt"A" xx tt"A" xx ...\`

making it an exponential type.

[You can even take derivatives of types!](http://strictlypositive.org/diff.pdf) (h/t Sam Tobin-Hochstadt for pointing this out to me)

# What, in the name of sanity, is a Pi type?

img

It’s essentially a form of dependent type. A dependent type is when your type can depend on a value. An example of this
is integer generics, where you can do things like `Array<bool, 5>`, or `template<unsigned int N, typename T> Array<T, N> ...` (in C++).

Note that the type signature contains a type dependent on an integer, being generic over multiple different array lengths.

The name comes from how a constructor for these types would look:

```
// create an array of booleans from a given integer
// I made up this syntax, this is _not_ from the Rust Pi type RFC
fn make_array(x: u8) -> Array<bool, x> {
    // ...
}

// or
// (the proposed rust syntax)
fn make_array<const x: u8>() -> Array<bool, x> {
   // ...
}
```

What’s the type of `make_array` here? It’s a function which can accept any integer and return a different type in each case.
You can view it as a set of functions, where each function corresponds to a different integer input. It’s basically:

```
struct make_array {
    make_array_0: fn() -> Array<bool, 0>,
    make_array_1: fn() -> Array<bool, 1>,
    make_array_2: fn() -> Array<bool, 2>,
    make_array_3: fn() -> Array<bool, 3>,
    make_array_4: fn() -> Array<bool, 4>,
    make_array_5: fn() -> Array<bool, 5>,
    // ...
}
```

Given an input, the function chooses the right child function here, and calls it.

This is a struct, or a product type! But it’s a product of an infinite number of types[^7].

We can look at it as

\`tt"make_array" = prod_{x = 0}^{oo} (tt"fn()" to tt"Array<bool, x>")\`

The usage of the \`prod\` symbol to denote an iterative product gives this the name “Pi type”.

In languages with lazy evaluation (like Haskell), there is no difference between having a function that can
give you a value, and actually having the value. So, the type of `make_array` is the type of `Array<bool, N>` itself
in languages with lazy evaluation.

There’s also a notion of a “sigma” type, which is basically

\`sum_{x = 0}^{oo} (tt"fn()" to tt"Array<bool, x>")\`

With the Pi type, we had “for all N we can construct an array”, with the sigma type we have “there exists some N for which we
can construct this array”. As you can expect, this type can be expressed with a possibly-infinite enum, and instances of this type
are basically instances of `Array<bool, N>` for some specific `N` where the `N` is only known at runtime. (much like how regular
sum types are instances of one amongst multiple types, where the exact type is only known at runtime). `Vec<bool>` is conceptually
similar to the sigma type `Array<bool, ?>`, as is `&[bool]`.

# Wrapping up

Types are sets, and we can do set-theory things on them to make cooler types.

Let’s try to avoid using confusing terminology, however. If Rust does get “pi types”, let’s just call them “dependent types”
or “const generics” :)

Thanks to Zaki, Avi Weinstock, Corey Richardson, and Peter Atashian for reviewing drafts of this post.

[^1]: Rust, Swift, sort of Typescript, and all the functional languages who had it before it was cool.
[^2]: Lookin’ at you, Go.
[^3]: Moooooooooooooooonads
[^4]: Types are not exactly sets due to some differences, but for the purposes of this post we can think of them like sets.
[^5]: Though you can argue that strings often have their length bounded by the pointer size of the platform, so it’s still a finite set.
[^6]: This even holds for zero-sized types, for more examples, check out this blog post
[^7]: Like with strings, in practice this would probably be bounded by the integer type chosen
[pi-types-rfc]: https://github.com/ticki/rfcs/blob/pi-types-2/text/0000-pi-types.md
[dragons]: https://ru.wikipedia.org/wiki/Компиляторы:_принципы,_технологии_и_инструменты
[set]: https://ru.wikipedia.org/wiki/Множество
