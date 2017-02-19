# Неофициальный русскоязычный сайт о Rust

[![Build Status](https://travis-ci.org/ruRust/rustycrate.ru.svg?branch=master)](https://travis-ci.org/ruRust/rustycrate.ru)
[![ruRust/rustycrate.ru](http://issuestats.com/github/ruRust/rustycrate.ru/badge/pr?style=flat)](http://issuestats.com/github/ruRust/rustycrate.ru)
[![ruRust/rustycrate.ru](http://issuestats.com/github/ruRust/rustycrate.ru/badge/issue?style=flat)](http://issuestats.com/github/ruRust/rustycrate.ru)
[![Join the chat at https://gitter.im/ruRust/rustycrate.ru](https://badges.gitter.im/ruRust/rustycrate.ru.svg)](https://gitter.im/ruRust/rustycrate.ru?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

# Обзор проекта

Сайт работает на [Jekyll](https://habrahabr.ru/post/207650/). Это статический
генератор сайтов. Когда мы запускаем `jekyll build`, Jekyll обрабатывает шаблоны
[Liquid](https://github.com/Shopify/liquid/wiki), и мы получаем полностью
готовый к развёртыванию сайт в директории `_site`. В процессе построения сайта
Jekyll склеивает файлы, заменяет специальные теги на свойства страниц,
генерирует определённые элементы в цикле и т.д. Пример шаблонной страницы можно
увидеть
[здесь](https://github.com/ruRust/rustycrate.ru/blob/master/index.html) - это
главная нашего сайта. Этот файл довольно подробно аннотирован комментариями - в
нём можно разобраться.

Развёртывание сайта - это просто копирование файлов в директорию, которую
раздаёт веб-сервер (например, nginx).

Вся динамичность и изменяемое содержимое достигается за счёт сторонних сервисов.
Наш сайт находится в репозитории на GitHub. Мы пишем новые публикации в виде
Pull Request'ов. Когда PR принят, Travis делает `jekyll build`, получает
статический сайт, и разворачивает его на сервере. Так достигается динамичность
публикаций.

Комментарии реализованы на Disqus. Disqus просто берёт id страницы (в нашем
случае это часть URL, не включающая имя сайта: например,
`/%D0%BE%D0%B1%D1%83%D1%87%D0%B5%D0%BD%D0%B8%D0%B5/2016/03/17/debugging-rust-with-gdb.html`)
и привязывает к нему набор комментариев, которые грузятся и отправляются
асинхронно с помощью JavaScript. Они хранятся в Disqus, а не у нас.

# Структура проекта

`_config.yml` - конфигурация Jekyll.

Файлы в корне с расширениями `.html`, `.xml` или `.md` - это страницы сайта. Они
должны иметь "front matter" (обложку), в которой указан вид страницы и другая
метаинформация. Эти файлы становятся простыми файлами `.html` после обработки
Jekyll и сохраняют своё базовое имя. Например, `in-progress.md` превращается в
`in-progress.html`.

`Gemfile` - это описание проекта Ruby. Jekyll написан на Ruby, и мы пользуемся
пакетами Ruby для расширения функциональности. Также мы используем
[bundler](https://habrahabr.ru/post/85201/) для управления зависимостями.

`Gemfile.lock` - это файл, фиксирующий конкретные версии зависимостей.
Используется Bundler.

`.travis.yml` - это конфигурация [Travis](https://habrahabr.ru/post/128277/).

Теперь о директориях. Все директории, начинающиеся с `_`, являются стандартными
для сайтов на Jekyll.

`css` - директория со стилями. Там почти все стили откуда-то взяты (из
Bootstrap, например). Главный файл - `main.scss`. Он включает в себя
`_sass/style.scss` и больше ничего. `_sass/style.scss` - это главный файл
стилей.

`fonts` - директория со шрифтами. Сейчас там только `glyphicons` из Bootstrap.

`images` - директория с картинками. Картинки к определённой публикации должны
лежать в директории, которая называется так же, как и файл с публикацией.

`_includes` - директория с частями HTML-файлов, которые включаются в готовые
страницы с помощью Liquid. Например, `head.html` - это содержимое HTML-тега
`head`, которое является общим для всех страниц сайта.

`js` - директория со скриптами. Никаких интересных скриптов здесь нет - всё
взято из Bootstrap.

`_layouts` - директория с шаблонами страниц. Например, `post.html` описывает
шаблон страницы публикации.

`_locales` - директория с файлами локализации.

`_plugins` - директория с плагинами. Они являются исходным кодом на Ruby.

`_posts` - директория с публикациями. Публикации написаны в формате Markdown.
Поддерживаются все основные расширения, как на GitHub.

В директории `_site` появляется сгенерированный сайт, когда вы запускаете
Jekyll.

# Локальный запуск

Для локального запуска нужен Ruby.

Рекомендуемая версия - 2.2.3.

Рекомендуемый способ установки - [RVM](https://rvm.io).

RVM нужен, чтобы легко поставить нужную версию Ruby. Вот как его установить:

```
gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3
\curl -sSL https://get.rvm.io | bash -s stable --ruby=2.2.3
```

После этого откройте новый терминал и сделайте:

```
rvm use --default 2.2.3
```

Затем в том же терминале клонируем и собираем сайт:

```
git clone https://github.com/ruRust/rustycrate.ru.git
cd rustycrate.ru
gem install bundler
bundle install --path vendor/bundle
bundle exec jekyll serve
```

## Если не собирается

Пишите в [Gitter-чат этого сайта][1] - мы поможем разобраться.

[1]: https://gitter.im/ruRust/rustycrate.ru
