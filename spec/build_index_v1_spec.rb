# frozen_string_literal: true

RSpec.describe IndexV1 do
  describe ".row_id" do
    # The primary entry is deliberately NOT first here. With it first, this
    # example cannot tell `detect(&:primary)` from a plain `first`.
    it "takes the primary docidentifier, wherever it sits" do
      doc = { "docidentifier" => [{ "content" => "not primary" },
                                  { "content" => "XEP 0060", "primary" => true }] }
      expect(described_class.row_id(doc)).to eq "XEP 0060"
    end

    # `Relaton::Xsf::DataFetcher#save_doc` falls back to the first entry, and
    # this has to match it or the two files disagree about a document's id.
    it "falls back to the first when none is marked primary" do
      doc = { "docidentifier" => [{ "content" => "XEP 0001" },
                                  { "content" => "XEP 0002" }] }
      expect(described_class.row_id(doc)).to eq "XEP 0001"
    end

    it "returns nil when there is no docidentifier" do
      expect(described_class.row_id({})).to be_nil
      expect(described_class.row_id({ "docidentifier" => [] })).to be_nil
    end

    it "returns nil when the entry carries no content" do
      expect(described_class.row_id({ "docidentifier" => [{ "type" => "XEP" }] }))
        .to be_nil
    end
  end

  describe ".write" do
    around { |example| Dir.mktmpdir { |dir| Dir.chdir(dir) { example.run } } }

    def write_doc(name, id)
      FileUtils.mkdir_p "data"
      body = { "docidentifier" => [{ "content" => id, "primary" => true }] }
      File.write "data/#{name}", body.to_yaml
    end

    # `crawler.rb` deletes `index-v1.yaml` before every crawl. A crawl that
    # fetched nothing would otherwise replace the published file with `--- []`.
    it "declines when data/ is missing" do
      expect(described_class.write).to be_nil
      expect(File).not_to exist(IndexV1::FILE)
    end

    it "declines when data/ holds no document" do
      FileUtils.mkdir_p "data"
      expect(described_class.write).to be_nil
      expect(File).not_to exist(IndexV1::FILE)
    end

    context "with a corpus" do
      before do
        write_doc "xep-0001.yaml", "XEP 0001"
        write_doc "xep-readme.yaml", "XEP README"
      end

      it "writes one row per document" do
        expect(described_class.write).to eq 2
        expect(rows.map { |r| r[:id] })
          .to contain_exactly("XEP 0001", "XEP README")
        expect(rows.map { |r| r[:file] })
          .to contain_exactly("data/xep-0001.yaml", "data/xep-readme.yaml")
      end

      # `index-v1` has no `pubid_class:`. A pubid hash here would not
      # deserialize in a released relaton v2 consumer.
      it "stores plain strings, not pubid hashes" do
        described_class.write
        expect(rows.map { |r| r[:id] }).to all be_a(String)
      end

      # A pooled Type outlives the file deletion `crawler.rb` does, so without
      # `remove_all` a second run would merge the previous run's rows in.
      it "rebuilds from scratch rather than merging a previous run" do
        described_class.write
        FileUtils.rm "data/xep-readme.yaml"
        expect(described_class.write).to eq 1
        expect(rows.map { |r| r[:id] }).to contain_exactly("XEP 0001")
      end
    end

    # Asserted on `Relaton.logger_pool`, not on `Relaton::Index::Util`.
    # `Util` has no `warn` of its own: `Kernel#warn` is a private method on the
    # module object, so an explicit-receiver call falls through to `Util`'s
    # `method_missing`, which forwards to the pool. A stub on `Util` inherits
    # that private visibility and is never reached.
    it "skips a document with no usable id, and warns" do
      write_doc "xep-0001.yaml", "XEP 0001"
      File.write "data/broken.yaml", { "title" => "no docidentifier" }.to_yaml
      expect(Relaton.logger_pool)
        .to receive(:warn).with(/broken\.yaml/, "relaton-index")
      expect(described_class.write).to eq 1
      expect(rows.map { |r| r[:id] }).to contain_exactly("XEP 0001")
    end

    # `add_or_update` keys on the id, so the second document replaces the
    # first instead of adding a row. Silent loss unless it says so.
    it "warns when two documents share a docidentifier" do
      write_doc "xep-0001.yaml", "XEP 0001"
      write_doc "xep-0001-dup.yaml", "XEP 0001"
      expect(Relaton.logger_pool)
        .to receive(:warn).with(/1 of 2 documents collapsed/, "relaton-index")
      expect(described_class.write).to eq 1
    end

    def rows
      YAML.safe_load(File.read(IndexV1::FILE), permitted_classes: [Symbol])
    end
  end

  # The acceptance test. Build `index-v1` from the real committed `data/` and
  # require it to be the published file, row for row. Nothing smaller proves
  # that all 520 documents survive, and any change to `row_id` has to keep it
  # green.
  describe "the published corpus" do
    around { |example| Dir.mktmpdir { |dir| Dir.chdir(dir) { example.run } } }

    before { FileUtils.ln_s File.join(REPO_ROOT, "data"), "data" }

    let(:published) do
      YAML.safe_load(File.read(File.join(REPO_ROOT, IndexV1::FILE)),
                     permitted_classes: [Symbol])
    end

    let(:built) do
      described_class.write
      YAML.safe_load(File.read(IndexV1::FILE), permitted_classes: [Symbol])
    end

    it "reproduces every published row" do
      # Sorted rather than `contain_exactly`, which compares 520 rows pairwise
      # and reports an unreadable diff on failure.
      by_file = ->(rows) { rows.sort_by { |r| r[:file] } }
      expect(by_file.call(built)).to eq by_file.call(published)
    end

    # The two non-documents the XMPP repository carries: its `README` and its
    # `xep-xxxx` template. Whether `index-v2` carries them depends on the pubid
    # resolved (see CLAUDE.md); this index always does, because it reads `data/`
    # and validates nothing. A released consumer looks them up today.
    it "keeps the two non-document rows, whatever pubid makes of them" do
      expect(built.size).to eq 520
      expect(built.map { |r| r[:id] }).to include("XEP README", "XEP xxxx")
    end
  end
end
