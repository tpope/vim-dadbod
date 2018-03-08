Follow the commit message style guide at [commit.style](https://commit.style).
If you don't, I'll know you didn't even read the first sentence of these
guidelines.

## Additional adapters

I'm quite interested in supporting additional databases, particularly big
names like Oracle and SQL Server.  For SQL databases, the MySQL adapter is
probably the best starting point.  Before starting on an adapter, check the
issue tracker to see if there's already a work in progress, and feel free to
open an issue if there's not one.

For interop adapters (e.g., Heroku, Ruby on Rails, etc.), I generally feel
those should live in separate plugins, unless you can name a good reason to
the contrary.

## Additional features

I'm open to a richer feature set, but that means starting from the ground up,
not blindly copying dbext.  Let's start by figuring out useful abstractions
before we map every variant of querying the table under the cursor.
