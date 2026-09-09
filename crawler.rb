#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'
require 'relaton/xsf'
require 'relaton/xsf/data_fetcher'
require_relative 'build_index_v1'

# Remove old files
FileUtils.rm_rf('data')
# Narrower than 'index*', which would also match a Ruby file named index*.rb
# next to it -- the crawler would then delete its own source. relaton-data-bipm
# hit that bug; spec/crawler_sources_spec.rb guards it here.
FileUtils.rm Dir.glob('index-v*.{yaml,zip}')

# Run converters. Writes data/ and index-v2.yaml only: the XSF flavor stopped
# writing index-v1. Nothing zips here -- relaton/support's shared crawler.yml
# zips every index*.yaml that changed and commits the yaml and the zip together.
Relaton::Xsf::DataFetcher.fetch

# Released relaton v2 consumers still read index-v1.zip from this branch, so
# build it from the data/ the fetch just wrote. See build_index_v1.rb for why
# data/ is the source rather than the index-v2 beside it.
rows = IndexV1.write

# Fail the run when the fetch produced nothing, and fail it LOUDLY.
#
# The deletions above have already happened by this point, and relaton/support's
# shared crawler.yml stages deletions -- `git add -u data/` -- then commits and
# pushes whatever is staged. So a scrape that returns no documents (an upstream
# markup change is enough) would otherwise publish the removal of the entire
# corpus and both indexes, unattended, with no operator action.
#
# `IndexV1.write` declining is not protection on its own: it only leaves the
# deleted index-v1.yaml unwritten. A non-zero exit is, because it fails the job
# and GitHub Actions then skips the "Push data" step.
abort "No documents fetched; refusing to publish an empty corpus" if rows.nil?
