# Kino.FS

Provides access to notebook files.

## file_path/1

Accesses notebook file with the given name and returns a local path
to read its contents from.

This invocation may take a while, in case the file is downloaded
from a URL and is not in the cache.

> #### File operations {: .info}
>
> You should treat the file as read-only. To avoid unnecessary
> copies the path may potentially be pointing to the original file,
> in which case any write operations would be persisted. This
> behaviour is not always the case, so you should not rely on it
> either.