
# Communicating Intent

Rust is an elegant language, that is quite different from many other popular languages. For example, instead of using classes and inheritance, Rust has a trait-based system. However I believe, that many programmers new to Rust (including myself) are unfamiliar with common Rust patterns.

In this post, I want to discuss the *newtype*-pattern, as well as the `From` and `Into` traits , which help with conversion between types.

---

Let's say we work for a european company building fancy, digital, IoT-ready thermostats for heaters. To ensure that water in heaters doesn't freeze (and thus damages heaters) we ensure in our software, that if there is a danger of freezing, we let hot water through. Thus somewhere in our software we have this function:

```rust
fn danger_of_freezing(temp: f64) -> bool;
```

It takes some temperature (provided by some WiFi-connected sensors) and adjusts the flow of water accordingly.

Everything goes well, customers are happy and no damaged heaters are found. Management decides to expand to the US and our company finds a local partner, which bundles their sensors with our state-of-the art thermostat.

It's a disaster.

After some investigation it is revealed that the American sensors reported temperatures in Fahrenheit, whilst the software for our thermostats works with Celsius. The software starts heating as soon as the temperature falls below 3° Celsius. Unfortunately, 3° Fahrenheit is way below the freezing point. Luckily, after a software update we can fix the problem and the damage is limited to just a few 10-thousands US-Dollars. [Others weren't so lucky.](https://en.wikipedia.org/wiki/Mars_Climate_Orbiter)


## Newtypes

The problem occurred, because we associated floating-point numbers with something more than just numbers. We have given these numbers a meaning without communicating it explicitly. Thus, instead of using plain numbers to represent temperature, we basically want to bundle them with a unit. Types to the rescue! 

```rust
#[derive(Debug, Clone, Copy)]
struct Celsius(f64);

#[derive(Debug, Clone, Copy)]
struct Fahrenheit(f64);
```

This is what Rustaceans call the `newtype`-pattern. It is a struct boxing a single value in a tuple-struct. In the example we created two newtypes, one each for Celsius and Fahrenheit.

Using these, our function in question now has this type-signature:

```rust
fn danger_of_freezing(temp: Celsius) -> bool;
```

Using this function with anything but Celsius-values results in compile time errors. Success!

### Conversions

All we have to do now is to write conversion functions, which can turn one unit into the other.

```rust
impl Celsius {
    to_fahrenheit(&self) -> Fahrenheit {
        Fahrenheit(self.0 * 9./5. + 32.)
    }
}

impl Fahrenheit {
    to_celsius(&self) -> Celsius {
        Celsius((self.0 - 32.) * 5./9.)
    }
}
```

And then use them like this:

```rust
let temp: Fahrenheit = sensor.read_temperature();
let is_freezing = danger_of_freezing(temp.to_celsius());
```

## From And Into

Conversion between different types is quite common in rust. For example we can turn `&str` to `String` using `to_string`, similarly to above:

```rust
// "Hello" has the type &'static str
let s = "Hello".to_string();
```

However, it is also possible to use ``String::from`` to create a string like this:

```rust
let s = String::from("hello");
```

And even this:

```rust
let s: String = "hello".into();
```

So why all these functions, when they are seemingly doing the same?

### Into the Wild

Rust offers traits, which unify conversions from one type into another. ``std::convert`` describes among others the `From` and `Into` traits.

```rust
pub trait From<T> {
    fn from(T) -> Self;
}

pub trait Into<T> {
    fn into(self) -> T;
}
```

As we can see above, ``String`` implements ``From<&str>`` and similarly ``&str`` implements ``Into<String>``. Actually, one has to only implement one of those two traits to gain both, since they are basically the same thing. To be more precise, [From implies Into](https://doc.rust-lang.org/src/core/up/src/libcore/convert.rs.html#267).


So let's do the same for temperatures:

```rust
impl From<Celsius> for Fahrenheit {
    fn from(c: Celsius) -> Self {
        Fahrenheit(c.0 * 9./5. + 32.)
    }
}

impl From<Fahrenheit> for Celsius {
    fn from(f: Fahrenheit) -> Self {
        Celsius((f.0 - 32.) * 5./9. )
    }
}
```

Applied to our function-call:
```rust
let temp: Fahrenheit = sensor.read_temperature();
let is_freezing = danger_of_freezing(temp.into());
// or
let is_freezing = danger_of_freezing(Celsius::from(temp));

```

### Your Wish Is My Command

Now, one could say that not much is gained by using the `From` trait over just implementing conversion functions -- as we did before. One could even argue the opposite, ``into`` is much less descriptive than ``to_celsius``.

What we can do though, is to move the unit-conversion into the function:

```rust
// T is anything which can be turned into Celsius
fn danger_of_freezing<T>(temp: T) -> bool
where T: Into<Celsius> {
    let celsius = Celsius::from(temp);
    ...
}
```

This function now magically accepts both Celsius and Fahrenheit as inputs, whilst remaining type-safe:

```rust
danger_of_freezing(Celsius(20.0));
danger_of_freezing(Fahrenheit(68.0));
```

We can even go a step further. Not only can we process a multitude of convertible inputs, but also produce several output-types in the same way.

Let's say we want a function, that returns the freezing point. It should return either Celsius or Fahrenheit -- depending on the context.
```rust
fn freezing_point<T>() -> T
where T: From<Celsius> {
    Celsius(0.0).into()
}
```

Calling this function is a bit different from other functions where we easily know the return type. Here we have to *request* the type we want.

```rust
// kindly requesting Fahrenheit
let temp: Fahrenheit = freezing_point();
```

There is a second, more explicit way to call the function:

```rust
// calling the function that returns Celsius
let temp = freezing_point::<Celsius>();
```

### Boxed Values

This technique is not only useful to convert units into each other, but can simplify handling of boxed values, e.g. query results from [databases](https://github.com/sfackler/rust-postgres).

```rust
let name: String = row.get(0);
let age: i32 = row.get(1);

// instead of
let name = row.get_string(0);
let age = row.get_integer(1);
```

## Summary

Python has a beautiful [Zen](https://www.python.org/dev/peps/pep-0020/). It first two lines say:
>Beautiful is better than ugly.
> Explicit is better than implicit.

Programming is the act of communicating intention to the computer. And we should be explicit with what we actually mean, when we write programs. For example, it is un-descriptive to use a boolean value to encode sort-order. In Rust we can just use an enum, to eliminate any ambiguity:

```rust
enum SortOrder {
    Ascending,
    Descending
}
```

In the same way newtypes help to attach meaning to plain values. A ``Celsius(f64)`` is different from ``Miles(f64)`` although they may share the same internal representation (``f64``). On the other hand the use of ``from`` and ``into`` help us, to keep programs and interfaces simpler. 
