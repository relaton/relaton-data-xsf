# frozen_string_literal: true

require 'relaton/xsf'
require 'relaton/xsf/data_fetcher'

# Remoeve old files
FileUtils.rm_rf('data')
FileUtils.rm Dir.glob('index*')

# Run converters
Relaton::Xsf::DataFetcher.fetch
