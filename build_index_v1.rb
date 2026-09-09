# frozen_string_literal: true

require "yaml"
require "relaton/index"

#
# The legacy `index-v1`, built from the crawled documents in `data/`.
#
# `Relaton::Xsf::DataFetcher` writes only `index-v2` now: its rows are
# `Pubid::Xsf::Identifier` objects serialized to a `_type: pubid:xsf:xep` hash.
# Released relaton v2 consumers still fetch `index-v1.zip` from this repository,
# so this repository has to keep producing it.
#
# It reads `data/`, NOT the `index-v2` the fetch just wrote. The sibling repos
# (relaton-data-ecma, relaton-data-w3c, relaton-data-iana, relaton-data-bipm)
# derive their v1 from their v2; three things make `data/` the better source
# here:
#
# 1. It does not depend on what pubid accepts. The crawled source carries two
#    non-documents, and older pubid revisions rejected their docids -- so a v1
#    derived from v2 was two rows shorter than the published file. See
#    {IndexV1.write}.
# 2. It needs no decline path keyed on `Relaton::Xsf::INDEXFILE`. A v2-derived
#    v1 has to refuse to run when the resolved relaton still writes v1, or it
#    publishes `--- []`. This works either way.
# 3. It never touches the fetcher's index pool entry. A v2-derived v1 has to
#    `Relaton::Index.close` first, because `Relaton::Index::Pool#type` upcases
#    its key and pools on the name, so `find_or_create` would otherwise hand
#    back the very object the fetcher filled.
#
# The cost, and `spec/build_index_v1_spec.rb` pins it: {.row_id} restates
# `Relaton::Xsf::DataFetcher#save_doc`'s id rule in a second place, where it can
# drift from the fetcher.
#
# Nothing here zips. relaton/support's shared `crawler.yml` zips every
# `index*.yaml` that changed and commits the yaml and the zip together.
#
module IndexV1
  FILE = "index-v1.yaml"
  DATA_GLOB = "data/*.yaml"

  # A pool key of its own, so these plain strings never land in the
  # pubid-typed `:xsf` entry the fetcher fills. `Relaton::Index::Pool#type`
  # upcases the key, so `:xsf` and `:XSF` are one entry and this is not.
  POOL_KEY = :XSF_V1

  class << self
    #
    # The `index-v1` row id of one crawled document.
    #
    # The same rule as `Relaton::Xsf::DataFetcher#save_doc`: the primary
    # docidentifier, or the first one when none is marked primary.
    #
    # Trivial for XSF, unlike ECMA's: an XEP identifier is a publisher and a
    # number with no edition, date or part, so the row id is the docidentifier
    # exactly as the document carries it -- nothing to split out.
    #
    # @param [Hash] doc a crawled document, as loaded from `data/`
    #
    # @return [String, nil] the row id, e.g. "XEP 0001", or nil if it has none
    #
    def row_id(doc)
      ids = doc["docidentifier"]
      return nil unless ids.is_a?(Array) && ids.any?

      (ids.detect { |i| i["primary"] } || ids.first)["content"]
    end

    #
    # Write `index-v1.yaml` from the documents the fetch wrote to `data/`.
    #
    # **This index always holds all 520 documents**, whatever pubid makes of
    # their docids. The crawled source carries the XMPP repository's `README`
    # and its `xep-xxxx` template, which reach the indexer as `XEP README` and
    # `XEP xxxx` and are not documents.
    #
    # `index-v2` has held either 518 or 520 depending on the pubid resolved:
    # older revisions rejected both docids, so
    # `Relaton::Xsf::DataFetcher#add_to_index` skipped them -- and had to, since
    # one unparseable row makes `Relaton::Index` declare the WHOLE file corrupt
    # and hand back an empty index. Current pubid parses them, so v2 carries
    # them too. See CLAUDE.md.
    #
    # None of that reaches here. These rows are plain strings that nothing
    # validates, and a released consumer looks those two up today.
    #
    # Declines on an empty corpus. `crawler.rb` deletes the index files before
    # every crawl, so a crawl that fetched nothing would otherwise replace the
    # published `index-v1.yaml` with `--- []`.
    #
    # @return [Integer, nil] rows written, or nil if it declined
    #
    def write
      files = Dir.glob(DATA_GLOB).sort
      return nil if files.empty?

      index = Relaton::Index.find_or_create(POOL_KEY, file: FILE)
      # Build from scratch. `crawler.rb` deletes the index files before a crawl,
      # but a pooled Type outlives that, and `add_or_update` would otherwise
      # merge this crawl's rows into a previous crawl's.
      index.remove_all
      indexed = 0
      files.each do |file|
        # `[Date, Time]` is insurance, not a current need: no document in
        # today's corpus carries an unquoted date. It costs nothing, and it
        # keeps a serializer change that starts emitting one from failing the
        # whole crawl at publish time.
        id = row_id(YAML.safe_load_file(file, permitted_classes: [Date, Time]))
        # Never index a nil id. It cannot happen in today's corpus (0 of 520),
        # and it must not pass silently if the document shape changes.
        if id.nil?
          Relaton::Index::Util.warn "No docidentifier in #{file}; not indexed"
          next
        end
        index.add_or_update id, file
        indexed += 1
      end
      index.save

      written = index.index.size
      # `add_or_update` keys on the id, so two documents sharing one docid
      # publish a single row and the second silently replaces the first. The
      # ids are unique across today's 520 documents; say so if that changes.
      if written < indexed
        Relaton::Index::Util.warn "#{indexed - written} of #{indexed} " \
                                  "documents collapsed onto an existing " \
                                  "index-v1 row"
      end
      written
    end
  end
end
