# dadbod.vim

Dadbod is a Vim plugin for interacting with databases.  It's a more modern
take on [dbext.vim][], improving on it on the following ways:

* Connections are specified with a single URL, rather than prompting you for
  14 separate variables
* All interaction is through invoking `:DB`, not 53 different commands and 35
  different maps (omitting many of the more esoteric features, of course)
* Supports a modern array of backends, including NoSQL databases:
  - Big Query
  - ClickHouse
  - DuckDB
  - Impala
  - jq
  - MongoDB
  - MySQL
  - MariaDB
  - Oracle
  - osquery
  - PostgreSQL
  - Presto
  - Redis
  - Snowflake
  - SQL Server
  - SQLite
  - Your own easily implemented adapter
* Easily configurable based on a project directory (as seen in [rails.vim][],
  for example), rather than just globally or in a per-file modeline
* For those that just can't live without some piece of dbext functionality,
  the option `g:dadbod_manage_dbext` is provided to force dbext to use
  Dadbod's default database.

## Usage

The `:DB` command has a few different usages.  All forms accept a URL as the
first parameter, which can be omitted if a default is configured or provided
by a plugin.

Omit further arguments to spawn an interactive console (like `psql` or
`redis-cli`).

    :DB postgresql:///foobar
    :DB redis:

If additional arguments are provided, they are interpreted as a query string
to pass to the database.  Results are displayed in a preview window.

    :DB sqlite:myfile.sqlite3 select count(*) from widgets
    :DB redis:/// CLIENT LIST

Give a range to run part or all of the current buffer as a query.

    :%DB mysql://root@localhost/bazquux

Use `<` to pass in a filename.

    :DB mongodb:///test < big_query.js

There's also a special assignment syntax for saving a URL to a Vim variable
for later use.

    :DB g:prod = postgres://user:pass@db.example.com/production_database
    :DB g:prod drop table users

A few additional URL like formats are accepted for interop:

* `:DB jdbc:sqlserver://...`
* `:DB dbext:profile=profile_name`
* `:DB dbext:type=PGSQL:host=...`
* `:DB $DATABASE_URL` (with optional [dotenv.vim][] support)

Plugins can provide their own URL handlers as well.  For example,
[heroku.vim][] provides support for `heroku:appname` style URLs.

If you want to manage multiple connections at once through UI,
try [dadbod-ui][].

[dbext.vim]: http://www.vim.org/script.php?script_id=356
[dotenv.vim]: https://tpope.io/vim/dotenv.git
[heroku.vim]: https://tpope.io/vim/heroku.git
[rails.vim]:  https://tpope.io/vim/rails.git
[dadbod-ui]:  https://github.com/kristijanhusak/vim-dadbod-ui

## Installation

Install using your favorite package manager, or use Vim's built-in package
support:

    mkdir -p ~/.vim/pack/tpope/start
    cd ~/.vim/pack/tpope/start
    git clone https://tpope.io/vim/dadbod.git
    vim -u NONE -c "helptags dadbod/doc" -c q

## Promotion

Like dadbod.vim?  Star the repository on
[GitHub](https://github.com/tpope/vim-dadbod) and vote for it on
[vim.org](https://www.vim.org/scripts/script.php?script_id=5665).

Love dadbod.vim?  Follow [tpope](http://tpo.pe/) on
[GitHub](https://github.com/tpope) and
[Twitter](http://twitter.com/tpope).

## License

Copyright © Tim Pope.  Distributed under the same terms as Vim itself.
See `:help license`.
