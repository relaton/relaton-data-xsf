# frozen_string_literal: true

require 'relaton_xsf'

# Remoeve old files
FileUtils.rm_rf('data')
FileUtils.rm Dir.glob('index*')

# Run converters
RelatonXsf::DataFetcher.fetch
