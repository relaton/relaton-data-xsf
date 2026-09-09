# frozen_string_literal: true

# `crawler.rb` deletes `data/` on load, so it cannot be required. Read it as
# source text instead, the way relaton-data-ecma, relaton-data-iana and
# relaton-data-bipm guard their own crawlers.
RSpec.describe "crawler.rb" do
  let(:source) { File.read(File.join(REPO_ROOT, "crawler.rb")) }

  # A bare `index*` glob also matches a Ruby file named index*.rb beside it, and
  # the crawler would delete the very source it requires. relaton-data-bipm hit
  # this exact bug, and `index_builder.rb` is a name a future session is likely
  # to add -- so guard that one too, not only the file here today.
  it "removes the generated index files, not a Ruby source beside them" do
    globs = source.scan(/Dir\.glob\(["']([^"']+)["']\)/).flatten
    expect(globs).not_to be_empty
    %w[build_index_v1.rb index_builder.rb crawler.rb].each do |ruby|
      globs.each do |glob|
        expect(File.fnmatch(glob, ruby, File::FNM_EXTGLOB))
          .to be(false), "glob #{glob.inspect} matches #{ruby}"
      end
    end
    %w[index-v1.yaml index-v1.zip index-v2.yaml index-v2.zip].each do |file|
      expect(globs.any? { |g| File.fnmatch(g, file, File::FNM_EXTGLOB) })
        .to be(true), "no glob matches #{file}"
    end
  end

  # Order is the contract: `IndexV1.write` indexes the `data/` files the fetch
  # wrote. Run first, it would find an empty corpus and decline.
  it "builds index-v1 after the fetch" do
    fetch = source.index("Relaton::Xsf::DataFetcher.fetch")
    build = source.index("IndexV1.write")
    expect(fetch).not_to be_nil
    expect(build).not_to be_nil
    expect(build).to be > fetch
  end

  # The crawler deletes `data/` and both indexes BEFORE the fetch, and
  # relaton/support's shared crawler.yml stages deletions (`git add -u data/`)
  # and pushes them. A scrape that returns nothing would publish the removal of
  # the whole corpus. Only a non-zero exit stops it, by failing the job so the
  # "Push data" step is skipped.
  it "aborts rather than publishing an empty corpus" do
    expect(source).to match(/^abort .+ if rows\.nil\?$/)
    expect(source.index("abort")).to be > source.index("IndexV1.write")
  end
end
