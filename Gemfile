# frozen_string_literal: true

source "https://rubygems.org"

# The XSF flavor lives in the combined `relaton` gem now, not in a `relaton-xsf`
# gem of its own, so `crawler.rb` requires "relaton/xsf/data_fetcher".
#
# The pin is `main` and not the released gem because the XSF index-v2 work is
# not in a release yet. It is on `main` (PR #152): `Relaton::Xsf::INDEXFILE`
# reads "index-v2", and the crawl writes that file.
gem "relaton", git: "https://github.com/relaton/relaton.git", branch: "main"

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
