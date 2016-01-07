require 'spec_helper'

describe GDor::Indexer::ModsFields do
  let(:fake_druid) { 'oo000oo0000' }
  let(:ns_decl) { "xmlns='#{Mods::MODS_NS}'" }
  let(:mods_xml) { "<mods #{ns_decl}><note>gdor_mods_fields testing</note></mods>" }
  let(:mods_origin_info_start_str) { "<mods #{ns_decl}><originInfo>" }
  let(:mods_origin_info_end_str) { '</originInfo></mods>' }

  def sdb_for_mods(m)
    resource = Harvestdor::Indexer::Resource.new(double, fake_druid)
    allow(resource).to receive(:public_xml).and_return(nil)
    allow(resource).to receive(:mods).and_return(Nokogiri::XML(m))
    i = Harvestdor::Indexer.new
    i.logger.level = Logger::WARN
    allow(resource).to receive(:indexer).and_return(i)
    lgr = Logger.new(StringIO.new)
    lgr.level = Logger::WARN
    GDor::Indexer::SolrDocBuilder.new(resource, lgr)
  end

  let(:sdb) { sdb_for_mods(mods_xml) }

  context 'publication date fields' do

    RSpec.shared_examples 'expected' do |solr_field_sym, mods_field_val, exp_val|
      it "#{exp_val} for #{mods_field_val}" do
        m = mods_origin_info_start_str +
              "<dateIssued>#{mods_field_val}</dateIssued>" +
            mods_origin_info_end_str
        sdb = sdb_for_mods(m)
        expect(sdb.doc_hash_from_mods[solr_field_sym]).to eq exp_val
      end
    end

    context 'pub_date (to know current behavior)' do
      it 'calls Stanford::Mods::Record instance pub_date_sortable_string(false)' do
        expect(sdb.smods_rec).to receive(:pub_date_facet)
        sdb.doc_hash_from_mods[:pub_date]
      end
      it 'includes approx dates' do
        m = mods_origin_info_start_str +
              "<dateIssued qualifier='approximate'>1945</dateIssued>" +
            mods_origin_info_end_str
        sdb = sdb_for_mods(m)
        expect(sdb.doc_hash_from_mods[:pub_date]).to eq('1945')
      end
      it 'takes single dateCreated' do
        m = mods_origin_info_start_str +
              "<dateCreated>1904</dateCreated>" +
            mods_origin_info_end_str
        sdb = sdb_for_mods(m)
        expect(sdb.doc_hash_from_mods[:pub_date]).to eq('1904')
      end
      it_behaves_like 'expected', :pub_date, 'blah blah 1945 blah', '1945'
      it_behaves_like 'expected', :pub_date, '1945', '1945'
      it_behaves_like 'expected', :pub_date, '945', '945'
      it_behaves_like 'expected', :pub_date, '66', nil
      it_behaves_like 'expected', :pub_date, '5', nil
      it_behaves_like 'expected', :pub_date, '0', nil
      it_behaves_like 'expected', :pub_date, '-4', nil
      it_behaves_like 'expected', :pub_date, '-15', nil
      it_behaves_like 'expected', :pub_date, '-666', '666' # WRONG
      it_behaves_like 'expected', :pub_date, '16--', nil
      it_behaves_like 'expected', :pub_date, '8--', nil
      it_behaves_like 'expected', :pub_date, '19th century', '19th century'
      it_behaves_like 'expected', :pub_date, '9th century', '9th century'
      it_behaves_like 'expected', :pub_date, '300 B.C.', '300 B.C.'
      it_behaves_like 'expected', :pub_date, 'Text dated June 4, 1594; miniatures added by 1596', '1594'
      it_behaves_like 'expected', :pub_date, 'Aug. 3rd, 1886', '1886'
      it_behaves_like 'expected', :pub_date, 'Aug. 3rd, [18]86?', '1886'
      it_behaves_like 'expected', :pub_date, 'early 1890s', '1890'
      it_behaves_like 'expected', :pub_date, '1865-6', '1865'

    end

    context 'pub_date_sort' do
      it 'calls Stanford::Mods::Record instance pub_date_sortable_string(false)' do
        expect(sdb.smods_rec).to receive(:pub_date_sortable_string).with(false)
        sdb.doc_hash_from_mods[:pub_date_sort]
      end
      it 'includes approx dates' do
        m = mods_origin_info_start_str +
              "<dateIssued qualifier='approximate'>1945</dateIssued>" +
            mods_origin_info_end_str
        sdb = sdb_for_mods(m)
        expect(sdb.doc_hash_from_mods[:pub_date_sort]).to eq('1945')
      end
      it 'takes single dateCreated' do
        m = mods_origin_info_start_str +
              "<dateCreated>1904</dateCreated>" +
            mods_origin_info_end_str
        sdb = sdb_for_mods(m)
        expect(sdb.doc_hash_from_mods[:pub_date_sort]).to eq('1904')
      end
      it_behaves_like 'expected', :pub_date_sort, '1945', '1945'
      it_behaves_like 'expected', :pub_date_sort, '945', '0945'
      it_behaves_like 'expected', :pub_date_sort, '66', '0066'
      it_behaves_like 'expected', :pub_date_sort, '5', '0005'
      it_behaves_like 'expected', :pub_date_sort, '0', '0000'
      # these negative values are for String lexical sorting as this is a string
      it_behaves_like 'expected', :pub_date_sort, '-4', '-996'
      it_behaves_like 'expected', :pub_date_sort, '-15', '-985'
      it_behaves_like 'expected', :pub_date_sort, '-666', '-334'
      it_behaves_like 'expected', :pub_date_sort, '16--', '1600'
      it_behaves_like 'expected', :pub_date_sort, '9--', '0900'
      it_behaves_like 'expected', :pub_date_sort, '19th century', '1800'
      it_behaves_like 'expected', :pub_date_sort, '9th century', '0800'
      # -(1000 - |yyy|) for BC dates
      it_behaves_like 'expected', :pub_date_sort, '300 B.C.', '-700'
    end

    context 'single valued pub year facets' do
      let(:mods) do
        mods_origin_info_start_str +
          "<dateIssued qualifier=\"approximate\">1500</dateIssued>
          <dateIssued>2000</dateIssued>" +
        mods_origin_info_end_str
      end
      it 'pub_year_no_approx_isi calls Stanford::Mods::Record instance pub_date_facet_single_value(true)' do
        sdb = sdb_for_mods(mods)
        expect(sdb.smods_rec).to receive(:pub_date_facet_single_value).with(true).and_call_original
        allow(sdb.smods_rec).to receive(:pub_date_facet_single_value).with(false) # for other flavor
        expect(sdb.doc_hash_from_mods[:pub_year_no_approx_isi]).to eq '2000'
      end
      it 'pub_year_w_approx_isi calls Stanford::Mods::Record instance pub_date_facet_single_value(false)' do
        sdb = sdb_for_mods(mods)
        expect(sdb.smods_rec).to receive(:pub_date_facet_single_value).with(false).and_call_original
        allow(sdb.smods_rec).to receive(:pub_date_facet_single_value).with(true) # for other flavor
        expect(sdb.doc_hash_from_mods[:pub_year_w_approx_isi]).to eq '1500'
      end
      RSpec.shared_examples "single pub year facet" do |field_sym|
        it_behaves_like 'expected', field_sym, '1945', '1945'
        it_behaves_like 'expected', field_sym, '945', '945'
        it_behaves_like 'expected', field_sym, '66', '66'
        it_behaves_like 'expected', field_sym, '5', '5'
        it_behaves_like 'expected', field_sym, '0', '0'
        it_behaves_like 'expected', field_sym, '-4', '4 B.C.'
        it_behaves_like 'expected', field_sym, '-15', '15 B.C.'
        it_behaves_like 'expected', field_sym, '-666', '666 B.C.'
        it_behaves_like 'expected', field_sym, '16--', '17th century'
        it_behaves_like 'expected', field_sym, '8--', '9th century'
        it_behaves_like 'expected', field_sym, '19th century', '19th century'
        it_behaves_like 'expected', field_sym, '9th century', '9th century'
        it_behaves_like 'expected', field_sym, '300 B.C.', '300 B.C.'
      end
      it_behaves_like "single pub year facet", :pub_year_no_approx_isi
      it_behaves_like "single pub year facet", :pub_year_w_approx_isi
    end

    context 'pub_year_tisim for date slider' do
      it 'should handle multiple pub dates (to be implemented - esp for date slider)'

      # FIXME:  it should be using a method approp for date slider values, not single value
      it 'pub_year_tisim calls Stanford::Mods::Record instance pub_date_sortable_string(false)' do
        expect(sdb.smods_rec).to receive(:pub_date_sortable_string).with(false)
        sdb.doc_hash_from_mods[:pub_year_tisim]
      end
      it 'includes approx dates' do
        m = mods_origin_info_start_str +
              "<dateIssued qualifier='approximate'>1945</dateIssued>" +
          mods_origin_info_end_str
        sdb = sdb_for_mods(m)
        expect(sdb.doc_hash_from_mods[:pub_year_tisim]).to eq('1945')
      end
      it 'takes single dateCreated' do
        m = mods_origin_info_start_str +
              "<dateCreated>1904</dateCreated>" +
            mods_origin_info_end_str
        sdb = sdb_for_mods(m)
        expect(sdb.doc_hash_from_mods[:pub_year_tisim]).to eq('1904')
      end
      it 'ignores B.C. dates' do
        m = mods_origin_info_start_str +
              "<dateCreated>300 B.C.</dateCreated>" +
          mods_origin_info_end_str
        sdb = sdb_for_mods(m)
        expect(sdb.doc_hash_from_mods).not_to have_key(:pub_year_tisim)
        expect(sdb.doc_hash_from_mods[:pub_year_tisim]).to be_nil
      end
      it_behaves_like 'expected', :pub_year_tisim, '1945', '1945'
      it_behaves_like 'expected', :pub_year_tisim, '945', '0945'
      it_behaves_like 'expected', :pub_year_tisim, '66', '0066'
      it_behaves_like 'expected', :pub_year_tisim, '5', '0005'
      it_behaves_like 'expected', :pub_year_tisim, '0', '0000'
      it_behaves_like 'expected', :pub_year_tisim, '-4', nil
      it_behaves_like 'expected', :pub_year_tisim, '-15', nil
      it_behaves_like 'expected', :pub_year_tisim, '-666', nil
      it_behaves_like 'expected', :pub_year_tisim, '16--', '1600'
      it_behaves_like 'expected', :pub_year_tisim, '9--', '0900'
      it_behaves_like 'expected', :pub_year_tisim, '19th century', '1800'
      it_behaves_like 'expected', :pub_year_tisim, '9th century', '0800'
      it_behaves_like 'expected', :pub_year_tisim, 'Text dated June 4, 1594; miniatures added by 1596', '1594'
      it_behaves_like 'expected', :pub_year_tisim, 'Aug. 3rd, 1886', '1886'
      it_behaves_like 'expected', :pub_year_tisim, 'Aug. 3rd, [18]86?', '1886'
      it_behaves_like 'expected', :pub_year_tisim, 'early 1890s', '1890'
      it_behaves_like 'expected', :pub_year_tisim, '1865-6', '1865' # FIXME:  should be both years
    end

    context 'creation_year_isi' do
      it 'creation_year_isi calls Stanford::Mods::Record pub_date_best_sort_str_value for dateCreated elements' do
        m = mods_origin_info_start_str +
              "<dateCreated qualifier='approximate'>1500</dateCreated>
              <dateIssued qualifier='approximate'>2000</dateIssued>" +
            mods_origin_info_end_str
        sdb = sdb_for_mods(m)
        expect(sdb.smods_rec).to receive(:pub_date_best_sort_str_value).at_least(2).times.and_call_original
        expect(sdb.doc_hash_from_mods[:creation_year_isi]).to eq '1500'
      end
      RSpec.shared_examples 'expected for dateCreated' do |mods_field_val, exp_val|
        it "#{exp_val} for #{mods_field_val}" do
          m = mods_origin_info_start_str +
                "<dateCreated>#{mods_field_val}</dateCreated>" +
              mods_origin_info_end_str
          sdb = sdb_for_mods(m)
          expect(sdb.doc_hash_from_mods[:creation_year_isi]).to eq exp_val
        end
      end
      it_behaves_like 'expected for dateCreated', '1945', '1945'
      # note that it removes leading zeros
      it_behaves_like 'expected for dateCreated', '945', '945'
      it_behaves_like 'expected for dateCreated', '66', '66'
      it_behaves_like 'expected for dateCreated', '5', '5'
      it_behaves_like 'expected for dateCreated', '0', '0'
      it_behaves_like 'expected for dateCreated', '-4', '-4'
      it_behaves_like 'expected for dateCreated', '-15', '-15'
      it_behaves_like 'expected for dateCreated', '-666', '-666'
      it_behaves_like 'expected for dateCreated', '16--', '1600'
      it_behaves_like 'expected for dateCreated', '9--', '900'
      it_behaves_like 'expected for dateCreated', '19th century', '1800'
      it_behaves_like 'expected for dateCreated', '9th century', '800'
      it_behaves_like 'expected for dateCreated', 'blah June 4, 1594; blah 1596', '1594'
      it_behaves_like 'expected for dateCreated', 'Aug. 3rd, 1886', '1886'
      it_behaves_like 'expected for dateCreated', 'Aug. 3rd, [18]86?', '1886'
      it_behaves_like 'expected for dateCreated', 'early 1890s', '1890'
      it_behaves_like 'expected for dateCreated', '1865-6', '1865'
      # note: B.C. becomes a regular negative number
      it_behaves_like 'expected for dateCreated', '300 B.C.', '-300'
    end

    context 'publication_year_isi' do
      it 'publication_year_isi calls Stanford::Mods::Record pub_date_best_sort_str_value for dateIssued elements' do
        m = mods_origin_info_start_str +
              "<dateCreated qualifier='approximate'>1500</dateCreated>
              <dateIssued qualifier='approximate'>2000</dateIssued>" +
            mods_origin_info_end_str
        sdb = sdb_for_mods(m)
        expect(sdb.smods_rec).to receive(:pub_date_best_sort_str_value).at_least(2).times.and_call_original
        expect(sdb.doc_hash_from_mods[:publication_year_isi]).to eq '2000'
      end
      it_behaves_like 'expected', :publication_year_isi, '1945', '1945'
      # note that it removes leading zeros
      it_behaves_like 'expected', :publication_year_isi, '945', '945'
      it_behaves_like 'expected', :publication_year_isi, '66', '66'
      it_behaves_like 'expected', :publication_year_isi, '5', '5'
      it_behaves_like 'expected', :publication_year_isi, '0', '0'
      it_behaves_like 'expected', :publication_year_isi, '-4', '-4'
      it_behaves_like 'expected', :publication_year_isi, '-15', '-15'
      it_behaves_like 'expected', :publication_year_isi, '-666', '-666'
      it_behaves_like 'expected', :publication_year_isi, '16--', '1600'
      it_behaves_like 'expected', :publication_year_isi, '9--', '900'
      it_behaves_like 'expected', :publication_year_isi, '19th century', '1800'
      it_behaves_like 'expected', :publication_year_isi, '9th century', '800'
      it_behaves_like 'expected', :publication_year_isi, 'blah June 4, 1594; blah 1596', '1594'
      it_behaves_like 'expected', :publication_year_isi, 'Aug. 3rd, 1886', '1886'
      it_behaves_like 'expected', :publication_year_isi, 'Aug. 3rd, [18]86?', '1886'
      it_behaves_like 'expected', :publication_year_isi, 'early 1890s', '1890'
      it_behaves_like 'expected', :publication_year_isi, '1865-6', '1865'
      # note: B.C. becomes a regular negative number
      it_behaves_like 'expected', :publication_year_isi, '300 B.C.', '-300'
    end
  end # publication date fields

  context 'imprint_display' do
    # FIXME:  it should be using a method returning a better string than just year
    it 'imprint_display calls deprecated Stanford::Mods::Record instance pub_date_display' do
      expect(sdb.smods_rec).to receive(:pub_date_display)
      sdb.doc_hash_from_mods[:imprint_display]
    end
    it_behaves_like 'expected', :imprint_display, '1945', '1945'
    it_behaves_like 'expected', :imprint_display, '945', '945'
    it_behaves_like 'expected', :imprint_display, '66', '66'
    it_behaves_like 'expected', :imprint_display, '5', '5'
    it_behaves_like 'expected', :imprint_display, '0', '0'
    it_behaves_like 'expected', :imprint_display, '-4', '-4'
    it_behaves_like 'expected', :imprint_display, '-15', '-15'
    it_behaves_like 'expected', :imprint_display, '-666', '-666'
    it_behaves_like 'expected', :imprint_display, '16--', '16--'
    it_behaves_like 'expected', :imprint_display, '9--', '9--'
    it_behaves_like 'expected', :imprint_display, '19th century', '19th century'
    it_behaves_like 'expected', :imprint_display, '9th century', '9th century'
    it_behaves_like 'expected', :imprint_display, 'blah June 4, 1594; blah 1596', 'blah June 4, 1594; blah 1596'
    it_behaves_like 'expected', :imprint_display, 'Aug. 3rd, 1886', 'Aug. 3rd, 1886'
    it_behaves_like 'expected', :imprint_display, 'Aug. 3rd, [18]86?', 'Aug. 3rd, [18]86?'
    it_behaves_like 'expected', :imprint_display, 'early 1890s', 'early 1890s'
    it_behaves_like 'expected', :imprint_display, '1865-6', '1865-6'
  end
end
