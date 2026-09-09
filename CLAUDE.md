# relaton-data-xsf

The XSF bibliographic corpus -- the XMPP XEP specifications -- crawled from
https://xmpp.org/extensions/refs/ by `crawler.rb`, which drives the XSF flavor
of the `relaton` gem.

Branch `v2` is the published branch. relaton reads it directly:
`Relaton::Xsf::HitCollection`'s `GHDATA_URL` is
`https://raw.githubusercontent.com/relaton/relaton-data-xsf/v2/`.

## Two index files

| File | Rows | Written by | Read by |
|---|---|---|---|
| `index-v2.yaml` / `.zip` | 520, `Pubid::Xsf::Identifier`, `_type: pubid:xsf:xep` | `Relaton::Xsf::DataFetcher` | relaton v3 |
| `index-v1.yaml` / `.zip` | 520, plain strings | `build_index_v1.rb`, here | released relaton v2 clients |

The XSF flavor stopped writing `index-v1`. `Relaton::Xsf::INDEXFILE` is
`index-v2`, and all three index call sites pass
`pubid_class: ::Pubid::Xsf::Identifier`. Released relaton v2 consumers still
fetch `index-v1.zip` from this branch, so this repository has to keep producing
it.

`.zip` companions are built by `relaton/support`'s shared `crawler.yml`, which
zips any changed `index*.yaml` and commits both. Nothing here zips.

## `index-v1` is built from `data/`, not from `index-v2`

The sibling repos (relaton-data-ecma, -w3c, -iana, -bipm) derive their v1 from
the v2 the fetcher just wrote. This one reads the crawled documents instead.
Every document carries its id in a fixed place:

```yaml
docidentifier:
- content: XEP 0001
  type: XEP
  primary: true
```

Three reasons, in order of weight:

1. **It keeps all 520 rows.** See the asymmetry below.
2. **No decline path keyed on the gem.** A v2-derived v1 has to refuse to run
   unless `Relaton::Xsf::INDEXFILE` names `index-v2`, or a relaton that still
   writes v1 leaves no v2 and the save replaces the published `index-v1.yaml`
   with `--- []`. Reading `data/` works either way.
3. **No index-pool subtlety.** A v2-derived v1 has to call
   `Relaton::Index.close` before reading: `Relaton::Index::Pool#type` upcases
   its key and pools on the name, so `find_or_create` hands back the very object
   the fetcher filled. Nothing here touches the fetcher's `:xsf` entry --
   `IndexV1::POOL_KEY` is `:XSF_V1`.

The cost: `IndexV1.row_id` restates
`Relaton::Xsf::DataFetcher#save_doc`'s rule -- the primary docidentifier, or the
first when none is primary -- in a second place, where it can drift from the
fetcher. `spec/build_index_v1_spec.rb` pins it against the real corpus.

`IndexV1.write` still declines, on an **empty corpus** rather than on the gem's
constant. `crawler.rb` deletes the index files before every crawl, so a crawl
that fetched nothing would otherwise publish `--- []`.

## A zero-result crawl must fail the job

Declining is not enough on its own, and this is the sharpest edge in the
repository. `crawler.rb` deletes `data/` and both indexes **before** the fetch,
and relaton/support's shared `crawler.yml` stages deletions --
`git add -u data/` -- then runs
`git diff --staged --quiet || (git commit -m 'update documents' && git push)`.

So a scrape that returns no documents (an upstream markup change is enough)
would commit and push the removal of the entire published corpus, unattended.
`IndexV1.write` returning nil only leaves the already-deleted `index-v1.yaml`
unwritten; it restores nothing.

`crawler.rb` therefore ends in `abort ... if rows.nil?`. The non-zero exit fails
the job, and GitHub Actions skips the "Push data" step.
`spec/crawler_sources_spec.rb` pins it. Do not remove that line, and do not
rescue around it.

## The two non-documents, and why both indexes carry them

The crawled source holds the XMPP repository's `README` and its `xep-xxxx`
template. They reach the indexer as the docids `XEP README` and `XEP xxxx`, and
neither is a document. Both indexes carry them, so both hold **520** rows.

This was not always so, and the history matters because it is the reason
`Relaton::Xsf::DataFetcher#add_to_index` has a `rescue` around the parse at all:

* **Until pubid `29f11b0`**, `Pubid::Xsf::Identifier.parse` REJECTED both. The
  fetcher's `rescue` recorded them and skipped them, so `index-v2` had 518 rows
  against `index-v1`'s 520. That skip was not a nicety. One unparseable row does
  not fail that row -- `Relaton::Index` declares the **whole file** corrupt,
  deletes it, and hands back an **empty** index. Measured upstream: 518 good
  rows plus a single `XEP README` loads as 0 rows, with two INFO lines as the
  only trace.
* **From pubid `4ff9ac0`**, both parse: `XEP README` yields
  `{_type: pubid:xsf:xep, number: "README"}`. The guard never fires, `index-v2`
  carries them, and the file loads clean -- verified, 520 rows back through
  `Relaton::Index.find_or_create` with the `pubid_class:`.

So nothing is broken, but two non-documents are now indexed as XEPs, and a
lookup for `XEP README` resolves. relaton's own fixture
(`spec/xsf/fixtures/index-v2.zip`) still holds the older **518**. If that
divergence matters, the fix belongs in pubid -- an XEP number is digits -- or in
an explicit skip list in the fetcher. It does **not** belong here: this
repository publishes what the fetcher writes.

`index-v1` is unaffected either way. It stores plain strings and validates
nothing, it has always held all 520, and a released consumer looks those two up
today.

## Do not name a file `index*`

`crawler.rb` removes `index-v*.{yaml,zip}` before a crawl. A bare `index*` glob
also matches the Ruby files beside it, and relaton-data-bipm deleted its own
crawler source that way. Keep the Ruby files verb-named -- `build_index_v1.rb`
-- and keep the glob narrow. `spec/crawler_sources_spec.rb` guards both.

## Specs

`bundle exec rspec`. There is no Rakefile and no CI workflow for the specs; the
sibling data repos are the same.

`spec/spec_helper.rb` requires `build_index_v1.rb`, never `crawler.rb` --
`crawler.rb` deletes `data/` on load, so `spec/crawler_sources_spec.rb` reads it
as source text instead. The helper closes the `:XSF_V1` pool entry after every
example, because the pool is process-wide and keyed on the name alone.

The acceptance test builds `index-v1` from the real committed `data/` and
requires the result to be the published `index-v1.yaml`, row for row, all 520.
Any change to `row_id` has to keep it green.

Note for assertions on warnings: `Relaton::Index::Util` has no `warn` of its
own. `Kernel#warn` is a private method on the module object, so an
explicit-receiver call falls through to `Util#method_missing`, which forwards to
`Relaton.logger_pool`. A stub on `Util` inherits that private visibility and is
never reached -- assert on `Relaton.logger_pool`.

## Dependency pins

**`Gemfile` carries a TEMPORARY path pin** to a local checkout:

```ruby
gem "relaton", path: "../relaton"
```

It is a path dep and not a `git:` pin because the XSF `index-v2` work is **not
committed** in relaton/relaton. It is an uncommitted working-tree diff on
`main`, and no XSF branch exists on the remote, so a git pin resolves relaton
*without* it: `INDEXFILE` reads `index-v1`, the crawl writes that file, and no
`index-v2` is produced.

Two consequences:

* The path is relative and resolves only because the relaton checkouts are
  siblings. GitHub Actions checks out this repository alone, so the **Crawler
  workflow cannot resolve it** and stays red. It is the only workflow that
  reads this file: relaton/support's `data-deploy.yml` -- behind both "Deploy"
  and "Check index" -- writes its own Gemfile to `$RUNNER_TEMP` and sets
  `BUNDLE_GEMFILE` to it, so the Pages build is unaffected.
* To revert, once the XSF work is committed and pushed:
  `gem "relaton", git: "https://github.com/relaton/relaton.git", branch: "main"`.

`pubid` is pinned separately, and has to be: bundler reads a path or git gem's
**gemspec**, never its Gemfile, so relaton's own pubid pin does not reach this
bundle, and the installed gem set has no `Pubid::Xsf` at all. `Gemfile.lock` is
git-ignored, so CI resolves fresh on every crawl. Verify with
`bundle list | grep -E "relaton |pubid "` before trusting a generated index.
