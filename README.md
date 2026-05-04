# Python 2.7.18 for SCO OpenServer 5

A working build of [Python 2.7.18](https://www.python.org/) (April 2020 —
the final 2.7 release) for **SCO OpenServer 5.0.7**, including TLS
support via OpenSSL 1.0.2q.

```
$ python --version
Python 2.7.18

$ python -c 'import ssl; print ssl.OPENSSL_VERSION'
OpenSSL 1.0.2q  20 Nov 2018
```

Just want to run Python on your SCO box? Skip to **[Install](#install)**.

## Why?

SCO OpenServer 5 has no in-tree modern Python — the youngest publicly
available was a much older 2.x. 2.7.18 brings about a decade of bug
fixes and, importantly, modern TLS so HTTPS-using libraries (`urllib2`,
`requests`, etc.) actually work against contemporary servers.

Python 2 is end-of-life upstream, but it's the right target here:
3.x needs C99-and-later compiler features that GCC 2.95 (the SCO native
compiler) can't provide. 2.7 is the newest Python that builds with two
trivial source patches.

## Install

> **Fresh SCO box?** Install [curl with TLS](https://github.com/tachytelic/curl-7.88.1-for-SCO-OpenServer-5)
> first — that's the only file that needs to be transferred via `scp`/USB.
> After that, every release on tachytelic/* (including this one) fetches
> over HTTPS from GitHub.

The full install is ~30 MB packaged. Fetch and extract directly on the
SCO box:

```sh
# On the SCO box (assumes curl-with-TLS is on PATH — see curl-sco):
curl -LO https://github.com/tachytelic/Python-2.7.18-for-SCO-OpenServer-5/releases/download/v1.0.0/python-2.7.18-sco.tar.gz
gtar xzf python-2.7.18-sco.tar.gz
# or with stock tools: gunzip -c python-2.7.18-sco.tar.gz | /usr/bin/tar xf -
mv py_install /usr/local/python-2.7.18
ln -s /usr/local/python-2.7.18/bin/python /usr/local/bin/python
python --version       # → Python 2.7.18
```

Or untar in place (e.g. `/opt/python-2.7.18/`) and add its `bin/`
directory to your `PATH`. The interpreter looks for its standard
library relative to the binary's location, so you can put it anywhere.

The OpenSSL 1.0.2q used for TLS is **statically linked** into the
shipped `_ssl.so`, so there's no runtime OpenSSL dependency — the
binary works on any stock SCO 5.0.7 install.

## What's included

**Standard library modules that work** (48 verified):

| Category | Modules |
|---|---|
| Core | `os`, `sys`, `json`, `re`, `math`, `time`, `struct`, `datetime`, `collections`, `itertools`, `argparse`, `copy`, `unittest`, `logging`, `random` |
| I/O | `io`, `cPickle`, `pickle`, `csv`, `tempfile`, `shutil`, `mmap` |
| Network | `socket`, `_socket`, `select`, `urllib`, `urllib2`, `httplib`, `email` |
| TLS / crypto | `ssl` (OpenSSL 1.0.2q), `hashlib`, `hmac`, `_sha256`, `_sha512` |
| Compression | `zlib`, `gzip`, `tarfile`, `zipfile`, `bz2`, `binascii`, `base64` |
| Process | `subprocess` |
| Terminal | `_curses`, `readline`, `termios` |
| Other | `uuid`, `array`, `pyexpat` |

**What's not included**:

- `thread` / `threading` — SCO's threading model isn't compatible with CPython
- `ctypes` — needs libffi (not on SCO)
- `_sqlite3` — needs the SQLite development headers

`pip` isn't pre-installed, but `urllib2` over the working TLS gives you
a way to fetch wheels manually if needed.

## Quick test

```python
$ python
Python 2.7.18 (default, May 24 2022, 02:17:05)
[GCC 2.95.3 20010315 (release)] on sco_sv3
>>> import urllib2, json, hashlib
>>> r = urllib2.urlopen('https://api.github.com/repos/python/cpython')
>>> j = json.loads(r.read())
>>> j['full_name'], j['stargazers_count']
('python/cpython', ...)
>>> hashlib.sha256(b'hello').hexdigest()
'2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824'
```

## Building from source

You probably don't need to do this — the release tarball is what
`build.sh` produces. But if you want to rebuild:

This is a **native build, not a cross-build**. SCO's runtime loader
hides certain libc symbols from binaries linked by GNU ld on Linux,
which makes cross-compiling Python impractical. Native build with
the SCO-supplied GCC 2.95.3 sidesteps the issue.

### Requirements

On the SCO machine you need:

- `/usr/gnu/bin/gcc` (GCC 2.95.3) and `/usr/gnu/bin/gmake`
- `/usr/bin/patch`
- A static OpenSSL 1.0.2 install at `/usr/local/lib/{libssl,libcrypto}.a`
  with headers at `/usr/local/include/openssl/`. OpenSSL 1.0.2q is what
  was used for the prebuilt; any 1.0.2x should work. Build it with:

  ```sh
  ./Configure no-shared no-asm sco5-gcc
  make depend && make && make install
  ```

  (SCO's stock OpenSSL 0.9.7 is too old for modern TLS. If you skip
  this step, Python builds without `_ssl` and you lose HTTPS.)

### Build

```sh
# Copy this whole directory to the SCO box, then:
cd python-sco
./build.sh
```

The script downloads `Python-2.7.18.tgz` from python.org, applies the
two compatibility patches, runs `configure` with appropriate flags,
builds, runs `make install` to `./py_install/`, strips, and tars.

### What the patches do

`patches/` contains two tiny unified diffs:

- `pidt-short.patch` — adds `SIZEOF_PID_T == SIZEOF_SHORT` case to
  `posixmodule.c`. SCO's `pid_t` is `short`, which Python 2.7's
  posixmodule didn't anticipate.

- `socket-inet-addrstrlen.patch` — `#undef`s `_REENTRANT` (SCO has no
  reentrant `libsocket`) and removes a platform-specific guard around
  `INET_ADDRSTRLEN`.

Total: 1.2 KB of changes. Everything else in the Python 2.7.18 source
just works on SCO with GCC 2.95.

## Repository layout

```
patches/
  pidt-short.patch           SCO pid_t is short
  socket-inet-addrstrlen.patch  fix _REENTRANT and INET_ADDRSTRLEN guard

build.sh                     Native-build script (run on SCO)
```

The prebuilt 30 MB tarball isn't committed to the repo (would bloat
every clone). Grab it from the **[Releases](../../releases)** page.

## License

Python is © Python Software Foundation, distributed under the [PSF
License](https://docs.python.org/2.7/license.html). The prebuilt
binary is unmodified upstream Python 2.7.18 with the two patches in
this repo applied.

The patches and build script in this repo are released under the MIT
license — see [LICENSE](LICENSE).

## See also

If you're keeping a SCO OpenServer 5 box alive, head over to
[tachytelic.net's SCO OpenServer 5 binaries page](https://tachytelic.net/2017/07/sco-openserver-5-binaries/)
— it collects other compiled software for the platform (bash, rsync,
tar, wget, lzop, …) along with notes on running these systems day to
day.
