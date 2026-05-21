# MyGameBuilder S3 Archive

The MyGameBuilderDataArchive was a project to download and back up the entire
contents of the existing MyGameBuilder data. The archive is not included in
this repository. This document details the archive project and the resulting
archive itself.

The archive is a complete, static snapshot of the user-generated content
that lived in the public Amazon S3 bucket `JGI_test1`, which the original
MyGameBuilder (MGB) Flash client used as its content store. The archive
also includes metadata and decompressed, usable versions of the objects as
detailed below.

The MGB backend itself (the Rails server that lived at `http://50.18.54.95:3000`)
is offline and has been for years, but the underlying S3 bucket remains (at the
time of writing) anonymously readable. This archive was produced by walking that
bucket end to end and writing every object (bytes, HTTP metadata, and S3 custom
metadata) to disk.

> **Status:** complete and frozen. The source bucket is treated as static
> and no further objects are expected to be added.

---

## 1. Provenance

| Field | Value |
| --- | --- |
| Source bucket | `JGI_test1` |
| Endpoint | `https://s3.amazonaws.com/JGI_test1/...` |
| Access | Anonymous (public read), standard S3 REST `ListBucket` / `GetObject` |
| Reservation | All custom `x-amz-meta-*` headers preserved alongside the body |

---

## 2. Top-level layout


```
archive/
├── README.md
├── JGI_test1/                              <- all user and system content
│   ├── _index.json
│   ├── !system/                            <- the reserved system user
│   │   ├── _index.json
│   │   ├── -/                              <- reserved project; holds the system profile and tutorials
│   │   │   ├── _index.json
│   │   │   ├── profile/
│   │   │   │   ├── _index.json
│   │   │   │   └── ...                     <- (see JGI_test1/<user>/-/profile/ below)
│   │   │   └── tutorial/                   <- built-in MGB tutorials
│   │   │       ├── _index.json
│   │   │       ├── <name>                  <- raw object bytes for each tutorial
│   │   │       └── <name>.meta.json
│   │   └── badges/                         <- reserved project that holds MGB badges
│   │       ├── _index.json
│   │       └── tile/
│   │           ├── _index.json
│   │           ├── <name>.png              <- raw PNG bytes for each badge tile
│   │           └── <name>.png.meta.json
│   ├── <username>/
│   │   ├── _index.json
│   │   ├── -/                              <- reserved project; holds this user's profile
│   │   │   ├── _index.json
│   │   │   └── profile/
│   │   │       ├── _index.json
│   │   │       ├── user                    <- raw object bytes for public profile information
│   │   │       └── user.meta.json
│   │   └── <project>/
│   │       ├── _index.json
│   │       └── <piecetype>/                <- one of: tile, actor, map, screenshot
│   │           ├── _index.json
│   │           ├── <name>[.png]            <- raw object bytes; `.png` suffix on tiles and screenshots
│   │           ├── <name>[.xml|.json|.txt] <- decoded sibling for actors/maps/tutorials/profiles (see §3.4)
│   │           └── <name>[.png].meta.json
│   └── ...
└── client/                                 <- captured copies of the original websites (see §7)
    ├── mygamebuilder.com/                  <- the original landing page
    │   └── ...
    └── s3.amazonaws.com/apphost/           <- the Flash client host (MGB.html, MGB.swf, supporting assets)
        └── ...
```

Every directory in the JGI_test1 archive contains an `_index.json` file
that maps original S3 keys/prefixes to the on-disk name of the
corresponding file or subdirectory. See §3.3 for the schema.
`_index.json` is the canonical way to look up an S3 object in the archive;
the on-disk file names should be treated as opaque. The `client/` subtree
(§7) is its own self-contained website snapshot and is intentionally not
indexed.

The path under each user mirrors the S3 key shape used by the Flash client:

```
JGI_test1/{username}/{project}/{piecetype}/{name}
```

where `piecetype` is one of:

```
tile     actor     map     screenshot
```

Tile and screenshot bodies (both PNGs) carry a literal `.png` extension
on disk so they preview in file managers and browsers; actor, map,
tutorial, and profile bodies are stored without an extension because
they are not in a standard image/text format.

Two prefixes are special (under `JGI_test1/`):

- `!system/` - the reserved system user. Owns built-in tutorials and badges.
- `<user>/-/` - the reserved system project (literal directory name `-`),
  used for per-user content that isn't tied to a specific project (the user's
  public profile lives here). This does not exist for every user. Presumably
  users without a `-` project are deleted users.

The default project where a user's (optional) avatar lives is `project1`, and
the avatar itself is stored as a tile named `avatar`. The user profile object
is the `profile` piece named `user`. Each project may optionally have a tile
called `project.logo` which is used as the project's logo image.

---

## 3. Per-object files

For every S3 object the archive keeps two sibling files in the same
directory:

### 3.1 `<name>` - raw bytes

The exact body returned by `GetObject`, byte-for-byte. Tile and
screenshot bodies (both PNGs) are stored with a literal `.png` suffix
so they preview directly in file managers and browsers; all other piece
types are stored with no extension.

### 3.2 `<name>.meta.json` - per-object metadata sidecar

A small JSON document with any relevant metadata from the HTTP and S3:

```jsonc
{
  "key":           "alice/project1/tile/Brick",   // original S3 key (authoritative)
  "size":          1234,                          // byte length of the body
  "content_type":  "image/png",                   // HTTP Content-Type
  "etag":          "9e107d9d372bb6826bd81d3542a419d6",
  "last_modified": "Mon, 12 Oct 2009 17:50:00 GMT",
  "amz_meta": {                                   // raw x-amz-meta-* headers
    "width":  "32",
    "height": "32",
    "...":    "..."
  }
}
```

The `key` field is the **source of truth** for what this object is in S3.
To go in the other direction (S3 key -> on-disk file) use the per-directory
`_index.json` (§3.3).

### 3.3 `_index.json` - per-directory S3-key map

Every directory under `JGI_test1` contains an `_index.json` file that maps
original S3 keys and key prefixes to the on-disk name of the corresponding
file or subdirectory:

```jsonc
{
  "prefix": "alice/project1/tile",     // the S3 prefix this directory represents ("" at the archive root)
  "entries": {
    "alice/project1/tile/Brick":         "Brick.png",
    "alice/project1/tile/brick":         "brick~3f1a9c02.png",
    "alice/project1/tile/Crazy thing ":  "Crazy thing_.png"
  }
}
```

Keys point at body files (full S3 key) or subdirectories (S3 prefix
with a trailing `/`); values are the names of the files/folders on
disk inside the directory that holds the index. At the archive root
`prefix` is the empty string and the entries map each user prefix
(`"alice/"`, `"!system/"`, ...) to the corresponding top-level
directory name.

Only content entries are listed: per-object `.meta.json` sidecars,
decoded sibling files (§3.4), `_index.json` itself, and the
bookkeeping files at the archive root (`README.md`, `FORMATS.md`,
...) are intentionally omitted.

---

### 3.4 `<name>.xml` / `<name>.json` / `<name>.txt` - decoded sibling

For piece types whose raw body is not in a human-readable format,
the archive also stores a decoded sibling file next to the raw body
so the content is browseable without the original Flash client:

| Piece type | Raw body            | Decoded sibling        | Format |
| ---------- | ------------------- | ---------------------- | --- |
| actor      | `<name>`            | `<name>.xml`           | UTF-8 XML (zlib-decompressed; `{{{`/`}}}` rewritten back to `<`/`>`) |
| map        | `<name>`            | `<name>.json`          | JSON dump of the decoded layered grid (width, height, per-layer cell lists) |
| tutorial   | `<name>`            | `<name>.txt`           | UTF-8 text (zlib-decompressed `writeUTF` payload) |
| profile    | `<name>` (`user`)   | `<name>.txt` (`user.txt`) | UTF-8 text (zlib-decompressed `writeUTF` payload) |

Tile and screenshot bodies are already PNGs, so no decoded sibling is
written for them.

The decoded siblings are **derived artifacts**, not S3 objects: they
are not listed in `_index.json` and they have no `.meta.json`. The
raw body remains the canonical archived form; the decoded sibling can
always be regenerated from it. See [`data-formats.md`](./data-formats.md)
for the underlying byte-level format of each raw body.

---

## 4. Resolving an S3 key

The on-disk file names should be treated as opaque: some S3 leaves
cannot be stored verbatim on common filesystems and have been
rewritten on disk, so reversing a name back to its original key is
not reliable. Always use the per-directory `_index.json` (§3.3)
instead.

To locate the on-disk file for an S3 key, walk down from the archive
root one segment at a time, looking each prefix up in the current
directory's `_index.json` to learn the next on-disk directory name,
and finally looking the full key up to learn the body's on-disk leaf.
The reverse direction is just the body's sibling `.meta.json`: its
`key` field is the original S3 key, byte-for-byte.

---

## 5. Piece file formats

The byte-level format of every archived object body (tile, actor, map,
tutorial, screenshot, profile) is documented separately in
[`data-formats.md`](./data-formats.md). That document describes how to
read each piece type without the original Flash client.

The `x-amz-meta-*` headers (mirrored under `amz_meta` in each
`.meta.json`) carry a small set of common fields that complement the
body for every piece type:

| `amz_meta` key  | Meaning |
| --- | --- |
| `width`, `height` | Logical size of the piece (pixels for tiles, cells for maps, etc.). |
| `tilename`        | For actors and maps: the name of the tile piece used to draw it. Empty otherwise. |
| `blobencoding`    | Always `"0"` for archived bodies. |
| `comment`         | Author-supplied description, if any. |
| `acl`             | Original S3 ACL string (typically `"null"` or `"public-read"`). |

The `content_type` recorded in the sidecar is `image/png` for tiles and
`text/plain` for the other piece types (the client looks at
`piecetype`, not the HTTP type, to decide how to parse the body).

---

## 6. Content modifications applied after archival

The bytes in this archive are an honest copy of what was in the bucket,
with two intentional exceptions, documented here for transparency.

### 6.1 Reviewed-tile blackouts

A subset of user-uploaded tiles were reviewed and intentionally replaced
with a solid-black PNG of the **same pixel dimensions** as the original.
The bodies were overwritten in place; the `.meta.json` sidecars still
describe the original object (key, etag, last-modified, custom headers),
but the body now hashes differently from the recorded `etag`.

The tiles were replaced because they appeared to include, or
could plausibly include, photographs of identifiable real people.
A manual, best-effort review was performed on all tile PNGs with
at least 100 unique colors, using that threshold as a practical
proxy for photo-like content. This review may have missed low-color,
stylized, very small, or otherwise ambiguous images, and some
replaced tiles may have been false positives. The original metadata
sidecars were retained, so these files; current image bytes
intentionally differ from the original S3 etag values.

### 6.2 Propagated screenshot blackouts

Map screenshots are PNG renders of the maps as composed in the Flash
client, so any screenshot of a map that draws a replaced tile (§6.1)
would still display the original artwork. To keep the blackouts
consistent, every such screenshot was overwritten with a solid-black
PNG of the **same pixel dimensions** as the original. The dependency
chain used to find them is:

  replaced tile -> actors whose `animationTable` references it ->
  maps whose layers (background, active, foreground) reference those
  actors -> screenshots of those maps.

As with §6.1, the `.meta.json` sidecars still describe the original
object and the body now hashes differently from the recorded `etag`.

---


## 7. The `client/` snapshot

`client/` is a static, offline-viewable capture of the two web origins
that made up the original MyGameBuilder front end:

- `client/mygamebuilder.com/` - the original landing page at
  `https://www.mygamebuilder.com/`. Contains `index.html` and any assets
  it references (e.g. `bgwish.png`).
- `client/s3.amazonaws.com/apphost/` - the Flash client host that lived
  at `https://s3.amazonaws.com/apphost/`. Contains `MGB.html` (the
  embedding page), `MGB.swf` (the Flash client), `AC_OETags.js` (Adobe's
  Flash-detection helper used by `MGB.html`), the `history/` SWFObject
  history-tracking helpers (`history.css`, `history.js`), and the asset
  subdirectories the client loads at runtime (`carousel_images/`,
  `mascot_images/`, `game_music/`).

The pages and supporting files were recovered from the Internet Archive
Wayback Machine. They have been minimally edited to match the original
as served:

- Wayback Machine toolbars, banners, and injected `web.archive.org`
  rewrites have been removed so the markup matches what the live site
  served.
- Any link or asset reference that originally pointed at another file
  inside this snapshot has been rewritten to a relative path so the
  capture works when opened from disk or served from any host. References
  to external sites that are not part of this snapshot are left as their
  original absolute URLs.
- No other content edits have been made; the HTML, CSS, JavaScript, and
  binary assets are otherwise byte-identical to the Wayback captures
  they came from.

`MGB.swf` here is the original, unmodified Flash client as served from
`s3.amazonaws.com/apphost/MGB.swf`. Running it standalone will attempt
to reach the long-defunct production servers; it is included for
preservation, not as a working client.
