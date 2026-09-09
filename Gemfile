# frozen_string_literal: true

source "https://rubygems.org"

# TEMPORARY PATH PIN -- see CLAUDE.md, "Dependency pins".
#
# The XSF flavor lives in the combined `relaton` gem now, not in a `relaton-xsf`
# gem of its own, so `crawler.rb` requires "relaton/xsf/data_fetcher".
#
# It is a `path:` dep and not a `git:` pin for one reason: the XSF index-v2 work
# is NOT COMMITTED in that checkout. It is an uncommitted working-tree diff on
# `main` (lib/relaton/xsf.rb, data_fetcher.rb, hit_collection.rb, processor.rb),
# and no XSF branch exists on the remote. A git pin therefore resolves relaton
# WITHOUT the work: `Relaton::Xsf::INDEXFILE` reads "index-v1", the crawl writes
# that file, and no index-v2 is produced. Only the working tree carries it.
#
# The path is relative, and it resolves because the relaton checkouts are
# siblings. GitHub Actions checks out this repository alone, so the CRAWLER
# workflow cannot resolve it and stays red until the revert below. Only that
# workflow reads this file: relaton/support's data-deploy.yml -- behind both
# "Deploy" and "Check index" -- writes its own Gemfile to $RUNNER_TEMP and sets
# BUNDLE_GEMFILE to it, so the Pages build is unaffected by this pin.
#
# TODO: once the XSF work is committed and pushed to relaton/relaton, replace
# this line with:
#   gem "relaton", git: "https://github.com/relaton/relaton.git", branch: "main"
gem "relaton", path: "../relaton"

# This repository has to pin pubid itself. Bundler reads a path or git gem's
# GEMSPEC, never its Gemfile, so relaton's own pubid pin does not reach this
# bundle and the gemspec's released `~> 2.0.0.alpha.10` would be resolved
# instead -- and the installed gem set has no `Pubid::Xsf` at all.
# `Gemfile.lock` is git-ignored, so CI resolves fresh on every crawl. Verify
# with `bundle list | grep pubid` before trusting a generated index.
#
# `pubid/pubid`, not `metanorma/pubid`: the repository was renamed. GitHub still
# redirects the old path, but only until someone creates a new repository at the
# old name -- at which point the pin would silently resolve to a different
# repository instead of failing.
gem "pubid", git: "https://github.com/pubid/pubid.git", branch: "main"

group :development, :test do
  gem "rspec", "~> 3.13"
end
