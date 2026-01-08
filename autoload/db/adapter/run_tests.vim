source ../../db.vim
source ../url.vim
source ../adapter.vim
source snowflake.vim
source test_snowflake.vim

call TestSnowflakeAdapterDefault()
call TestSnowflakeAdapterCLI()
call TestSnowflakeCompleteDatabase()

:silent !echo "All tests passed"
