describe GDor::Indexer::SolrDocHash do
  context '#field_present?' do
    context 'actual field value is boolean true' do
      subject do
        described_class.new(a: true)
      end
      it 'true if expected value is nil' do
        expect(subject).to be_field_present(:a)
      end
      it 'false if expected value is String' do
        expect(subject).not_to be_field_present(:a, 'true')
      end
      it 'false if expected value is Regex' do
        expect(subject).not_to be_field_present(a: /true/)
      end
    end

    context 'expected value is nil' do
      subject { described_class.new({}) }
      it 'false if the field is not in the doc_hash' do
        expect(subject).not_to be_field_present(:any)
      end
      it 'false if hash[field] is nil' do
        subject[:foo] = nil
        expect(subject).not_to be_field_present(:foo)
      end
      it 'false if hash[field] is an empty String' do
        subject[:foo] = ''
        expect(subject).not_to be_field_present(:foo)
      end
      it 'true if hash[field] is a non-empty String' do
        subject[:foo] = 'bar'
        expect(subject).to be_field_present(:foo)
      end
      it 'false if hash[field] is an empty Array' do
        subject[:foo] = []
        expect(subject).not_to be_field_present(:foo)
      end
      it 'false if hash[field] is an Array with only empty String values' do
        subject[:foo] = ['', '']
        expect(subject).not_to be_field_present(:foo)
      end
      it 'false if hash[field] is an Array with only nil String values' do
        subject[:foo] = [nil]
        expect(subject).not_to be_field_present(:foo)
      end
      it 'true if hash[field] is a non-empty Array' do
        subject[:foo] = ['a']
        expect(subject).to be_field_present(:foo)
      end
      it 'false if doc_hash[field] is not a String or Array' do
        subject[:foo] = {}
        expect(subject).not_to be_field_present(:foo)
      end
    end

    context 'expected value is a String' do
      subject { described_class.new({}) }

      it 'true if hash[field] is a String and matches' do
        subject[:foo] = 'a'
        expect(subject).to be_field_present(:foo, 'a')
      end
      it "false if hash[field] is a String and doesn't match" do
        subject[:foo] = 'a'
        expect(subject).not_to be_field_present(:foo, 'b')
      end
      it 'true if hash[field] is an Array with a value that matches' do
        subject[:foo] = %w(a b)
        expect(subject).to be_field_present(:foo, 'a')
      end
      it 'false if hash[field] is an Array with no value that matches' do
        subject[:foo] = %w(a b)
        expect(subject).not_to be_field_present(:foo, 'c')
      end
      it 'false if hash[field] is not a String or Array' do
        subject[:foo] = {}
        expect(subject).not_to be_field_present(:foo, 'a')
      end
    end

    context 'expected value is Regex' do
      subject { described_class.new({}) }

      it 'true if hash[field] is a String and matches' do
        subject[:foo] = 'aba'
        expect(subject).to be_field_present(:foo, /b/)
      end
      it "false if hash[field] is a String and doesn't match" do
        subject[:foo] = 'aaaaa'
        expect(subject).not_to be_field_present(:foo, /b/)
      end
      it 'true if hash[field] is an Array with a value that matches' do
        subject[:foo] = %w(a b)
        expect(subject).to be_field_present(:foo, /b/)
      end
      it 'false if hash[field] is an Array with no value that matches' do
        subject[:foo] = %w(a b)
        expect(subject).not_to be_field_present(:foo, /c/)
      end
      it 'false if hash[field] is not a String or Array' do
        subject[:foo] = {}
        expect(subject).not_to be_field_present(:foo, /a/)
      end
    end
  end # field_present?

  context '#combine' do
    context 'orig has no key' do
      subject do
        described_class.new({})
      end

      it 'result has no key if new value is nil' do
        expect(subject.combine(foo: nil)).to eq({})
      end
      it 'result has no key if new value is empty String' do
        expect(subject.combine(foo: '')).to eq({})
      end
      it 'result has new value if new value is non-empty String' do
        expect(subject.combine(foo: 'bar')).to eq(foo: 'bar')
      end
      it 'result has no key if new value is empty Array' do
        expect(subject.combine(foo: [])).to eq({})
      end
      it 'result has new value new value is non-empty Array' do
        expect(subject.combine(foo: ['bar'])).to eq(foo: ['bar'])
      end
      it 'result has no key if new value is not String or Array' do
        expect(subject.combine(foo: {})).to eq({})
      end
    end # orig has no key
    context 'orig value is nil' do
      subject do
        described_class.new(foo: nil)
      end
      it 'result has no key if new value is nil' do
        expect(subject.combine(foo: nil)).to eq({})
      end
      it 'result has no key if new value is empty String' do
        expect(subject.combine(foo: '')).to eq({})
      end
      it 'result has new value if new value is non-empty String' do
        expect(subject.combine(foo: 'bar')).to eq(foo: 'bar')
      end
      it 'result has no key if new value is empty Array' do
        expect(subject.combine(foo: [])).to eq({})
      end
      it 'result has new value if new value is non-empty Array' do
        expect(subject.combine(foo: ['bar'])).to eq(foo: ['bar'])
      end
      it 'result has no key if new value is not String or Array' do
        expect(subject.combine(foo: {})).to eq({})
      end
    end # orig value is nil
    context 'orig value is empty String' do
      subject do
        described_class.new(foo: '')
      end
      it 'result has no key if new value is nil' do
        expect(subject.combine(foo: nil)).to eq({})
      end
      it 'result has no key if new value is empty String' do
        expect(subject.combine(foo: '')).to eq({})
      end
      it 'result has new value if new value is non-empty String' do
        expect(subject.combine(foo: 'bar')).to eq(foo: 'bar')
      end
      it 'result has no key if new value is empty Array' do
        expect(subject.combine(foo: [])).to eq({})
      end
      it 'result has new value if new value is non-empty Array' do
        expect(subject.combine(foo: ['bar'])).to eq(foo: ['bar'])
      end
      it 'result has no key if new value is not String or Array' do
        expect(subject.combine(foo: {})).to eq({})
      end
    end # orig value is empty String
    context 'orig value is non-empty String' do
      subject do
        described_class.new(foo: 'a')
      end
      it 'result is orig value if new value is nil' do
        expect(subject.combine(foo: nil)).to eq(foo: 'a')
      end
      it 'result is orig value if new value is empty String' do
        expect(subject.combine(foo: '')).to eq(foo: 'a')
      end
      it 'result is Array of old and new values if new value is non-empty String' do
        expect(subject.combine(foo: 'bar')).to eq(foo: %w(a bar))
      end
      it 'result is orig value if new value is empty Array' do
        expect(subject.combine(foo: [])).to eq(foo: 'a')
      end
      it 'result Array of old and new values if new value is non-empty Array' do
        expect(subject.combine(foo: %w(bar ness))).to eq(foo: %w(a bar ness))
      end
      it 'result is orig value if new value is not String or Array' do
        expect(subject.combine(foo: :bar)).to eq(foo: ['a', :bar])
      end
    end # orig value is String
    context 'orig value is empty Array' do
      subject do
        described_class.new(foo: [])
      end
      it 'result has no key if new value is nil' do
        expect(subject.combine(foo: nil)).to eq({})
      end
      it 'result has no key if new value is empty String' do
        expect(subject.combine(foo: '')).to eq({})
      end
      it 'result is new value if new value is non-empty String' do
        expect(subject.combine(foo: 'bar')).to eq(foo: 'bar')
      end
      it 'result has no key if new value is empty Array' do
        expect(subject.combine(foo: [])).to eq({})
      end
      it 'result is new values if new value is non-empty Array' do
        expect(subject.combine(foo: %w(bar ness))).to eq(foo: %w(bar ness))
      end
      it 'result has no key if new value is not String or Array' do
        expect(subject.combine(foo: {})).to eq({})
      end
    end # orig value is empty Array
    context 'orig value is non-empty Array' do
      subject do
        described_class.new(foo: %w(a b))
      end
      it 'result is orig value if new value is nil' do
        expect(subject.combine(foo: nil)).to eq(foo: %w(a b))
      end
      it 'result is orig value if new value is empty String' do
        expect(subject.combine(foo: '')).to eq(foo: %w(a b))
      end
      it 'result is Array of old and new values if new value is non-empty String' do
        expect(subject.combine(foo: 'bar')).to eq(foo: %w(a b bar))
      end
      it 'result is orig value if new value is empty Array' do
        expect(subject.combine(foo: [])).to eq(foo: %w(a b))
      end
      it 'result Array of old and new values if new value is non-empty Array' do
        expect(subject.combine(foo: %w(bar ness))).to eq(foo: %w(a b bar ness))
      end
      it 'result is orig value if new value is not String or Array' do
        expect(subject.combine(foo: :bar)).to eq(foo: ['a', 'b', :bar])
      end
    end # orig value is non-empty Array
  end # combine

  context '#validate_item' do
    let(:collection_druid) { 'xyz' }
    let(:mock_config) { Confstruct::Configuration.new }

    before do
      described_class.any_instance.stub(validate_gdor_fields: [])
    end

    it 'calls validate_gdor_fields' do
      hash = described_class.new({})
      expect(hash).to receive(:validate_gdor_fields).and_return([])
      hash.validate_item(mock_config)
    end
    it 'has a value if collection is wrong' do
      hash = described_class.new(collection: 'junk',
                                 collection_with_title: "#{collection_druid}-|-asdasdf",
                                 file_id: ['anything'])
      expect(hash).to receive(:validate_gdor_fields).and_return([])
      expect(hash.validate_item(mock_config).first).to match(/collection /)
    end
    it 'has a value if collection_with_title is missing' do
      hash = described_class.new(collection: collection_druid,
                                 collection_with_title: nil,
                                 file_id: ['anything'])
      expect(hash.validate_item(mock_config).first).to match(/collection_with_title /)
    end
    it 'has a value if collection_with_title is missing the title' do
      hash = described_class.new(collection: collection_druid,
                                 collection_with_title: "#{collection_druid}-|-",
                                 file_id: ['anything'])
      expect(hash.validate_item(mock_config).first).to match(/collection_with_title /)
    end
    it 'has a value if file_id field is missing' do
      hash = described_class.new(collection: collection_druid,
                                 collection_with_title: "#{collection_druid}-|-asdasdf",
                                 file_id: nil)
      expect(hash.validate_item(mock_config).first).to match(/file_id/)
    end
    it 'does not have a value if gdor_fields and item fields are ok' do
      hash = described_class.new(collection: collection_druid,
                                 collection_with_title: "#{collection_druid}-|-asdasdf",
                                 file_id: ['anything'])
      expect(hash.validate_item(mock_config)).to eq([])
    end
  end # validate_item

  context '#validate_collection' do
    let(:mock_config) { Confstruct::Configuration.new }

    before do
      described_class.any_instance.stub(validate_gdor_fields: [])
    end

    it 'calls validate_gdor_fields' do
      hash = described_class.new({})
      expect(hash).to receive(:validate_gdor_fields).and_return([])
      hash.validate_collection(mock_config)
    end
    it 'has a value if collection_type is missing' do
      hash = described_class.new(format_main_ssim: 'Archive/Manuscript')

      expect(hash.validate_collection(mock_config).first).to match(/collection_type/)
    end
    it "has a value if collection_type is not 'Digital Collection'" do
      hash = described_class.new(collection_type: 'lalalalala', format_main_ssim: 'Archive/Manuscript')
      expect(hash.validate_collection(mock_config).first).to match(/collection_type/)
    end
    it 'has a value if format_main_ssim is missing' do
      hash = described_class.new(collection_type: 'Digital Collection')
      expect(hash.validate_collection(mock_config).first).to match(/format_main_ssim/)
    end
    it "has a value if format_main_ssim doesn't include 'Archive/Manuscript'" do
      hash = described_class.new(format_main_ssim: 'lalalalala', collection_type: 'Digital Collection')
      expect(hash.validate_collection(mock_config).first).to match(/format_main_ssim/)
    end
    it 'does not have a value if gdor_fields, collection_type and format_main_ssim are ok' do
      hash = described_class.new(collection_type: 'Digital Collection', format_main_ssim: 'Archive/Manuscript')
      expect(hash.validate_collection(mock_config)).to eq([])
    end
  end # validate_collection

  context '#validate_gdor_fields' do
    let(:druid) { 'druid' }
    let(:purl_url) { mock_config.harvestdor.purl }
    let(:mock_config) do
      Confstruct::Configuration.new do
        harvestdor do
          purl 'https://some.uri'
        end
      end
    end

    it 'returns an empty Array when there are no problems' do
      hash = described_class.new(access_facet: 'Online',
                                 druid: druid,
                                 url_fulltext: "#{purl_url}/#{druid}",
                                 display_type: 'image',
                                 building_facet: 'Stanford Digital Repository')
      expect(hash.validate_gdor_fields(mock_config)).to eq([])
    end
    it 'has a value for each missing field' do
      hash = described_class.new({})
      expect(hash.validate_gdor_fields(mock_config).length).to eq(5)
    end
    it 'has a value for an unrecognized display_type' do
      hash = described_class.new(access_facet: 'Online',
                                 druid: druid,
                                 url_fulltext: "#{purl_url}/#{druid}",
                                 display_type: 'zzzz',
                                 building_facet: 'Stanford Digital Repository')
      expect(hash.validate_gdor_fields(mock_config).first).to match(/display_type/)
    end
    it "has a value for access_facet other than 'Online'" do
      hash = described_class.new(access_facet: 'BAD',
                                 druid: druid,
                                 url_fulltext: "#{purl_url}/#{druid}",
                                 display_type: 'image',
                                 building_facet: 'Stanford Digital Repository')
      expect(hash.validate_gdor_fields(mock_config).first).to match(/access_facet/)
    end
    it "has a value for building_facet other than 'Stanford Digital Repository'" do
      hash = described_class.new(access_facet: 'Online',
                                 druid: druid,
                                 url_fulltext: "#{purl_url}/#{druid}",
                                 display_type: 'image',
                                 building_facet: 'WRONG')
      expect(hash.validate_gdor_fields(mock_config).first).to match(/building_facet/)
    end
  end # validate_gdor_fields

  context '#validation_mods' do
    let(:mock_config) { {} }
    it 'has no validation messages for a complete record' do
      hash = described_class.new(modsxml: 'whatever',
                                 title_display: 'title',
                                 pub_year_tisim: 'some year',
                                 author_person_display: 'author',
                                 format_main_ssim: 'Image',
                                 format: 'Image',
                                 language: 'English')
      expect(hash.validate_mods(mock_config).length).to eq(0)
    end
    it 'has validation messages for each missing field' do
      hash = described_class.new(id: 'whatever')
      expect(hash.validate_mods(mock_config).length).to eq(7)
    end
  end
end
