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

    RSpec.shared_examples "expected" do |solr_field_sym, mods_field_val, exp_val|
      it "#{exp_val} for #{mods_field_val}" do
        m = mods_origin_info_start_str +
              "<dateIssued>#{mods_field_val}</dateIssued>" +
            mods_origin_info_end_str
        sdb = sdb_for_mods(m)
        expect(sdb.doc_hash_from_mods[solr_field_sym]).to eq exp_val
      end
    end

    # TODO:  this test is in the process of being incorporated into individual field tests below
    it 'populates all date fields' do
      m = mods_origin_info_start_str +
            "<dateIssued>blah blah 19th century blah blah</dateIssued>" +
          mods_origin_info_end_str
      sdb = sdb_for_mods(m)
      doc_hash = sdb.doc_hash_from_mods
      expect(doc_hash[:pub_date]).to eq('19th century') # deprecated due to new pub_year_ fields
      expect(doc_hash[:pub_date_sort]).to eq('1800') # covered in pub_date_sort tests
      expect(doc_hash[:pub_year_no_approx_isi]).to eq('19th century') # covered in tests below
      expect(doc_hash[:pub_year_w_approx_isi]).to eq('19th century') # covered in tests below
      expect(doc_hash[:publication_year_isi]).to eq('1800')
      expect(doc_hash[:pub_year_tisim]).to eq('1800') # covered in pub_year_tisim tests
      expect(doc_hash[:imprint_display]).to eq('blah blah 19th century blah blah') # covered in imprint_display tests
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
      it_behaves_like "expected", :pub_date_sort, '1945', '1945'
      it_behaves_like "expected", :pub_date_sort, '945', '0945'
      it_behaves_like "expected", :pub_date_sort, '16--', '1600'
      it_behaves_like "expected", :pub_date_sort, '9--', '0900'
      it_behaves_like "expected", :pub_date_sort, '19th century', '1800'
      it_behaves_like "expected", :pub_date_sort, '9th century', '0800'
      # -(1000 - |yyy|) for BC dates
      it_behaves_like "expected", :pub_date_sort, '300 B.C.', '-700'
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
        it_behaves_like "expected", field_sym, '1945', '1945'
        it_behaves_like "expected", field_sym, '945', '945'
        it_behaves_like "expected", field_sym, '16--', '17th century'
        it_behaves_like "expected", field_sym, '8--', '9th century'
        it_behaves_like "expected", field_sym, '19th century', '19th century'
        it_behaves_like "expected", field_sym, '9th century', '9th century'
        it_behaves_like "expected", field_sym, '300 B.C.', '300 B.C.'
      end
      it_behaves_like "single pub year facet", :pub_year_no_approx_isi
      it_behaves_like "single pub year facet", :pub_year_w_approx_isi
    end

    context 'pub_year_tisim for date slider' do
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
      it_behaves_like "expected", :pub_year_tisim, '1945', '1945'
      it_behaves_like "expected", :pub_year_tisim, '945', '0945'
      it_behaves_like "expected", :pub_year_tisim, '16--', '1600'
      it_behaves_like "expected", :pub_year_tisim, '9--', '0900'
      it_behaves_like "expected", :pub_year_tisim, '19th century', '1800'
      it_behaves_like "expected", :pub_year_tisim, '9th century', '0800'
      it_behaves_like "expected", :pub_year_tisim, 'Text dated June 4, 1594; miniatures added by 1596', '1594'
      it_behaves_like "expected", :pub_year_tisim, 'Aug. 3rd, 1886', '1886'
      it_behaves_like "expected", :pub_year_tisim, 'Aug. 3rd, [18]86?', '1886'
      it_behaves_like "expected", :pub_year_tisim, 'early 1890s', '1890'
      it_behaves_like "expected", :pub_year_tisim, '1865-6', '1865' # FIXME:  should be both years
    end

    # TODO:  these tests are in the process of being incorporated into individual field tests above
    context 'difficult pub dates' do
      it 'should handle multiple pub dates (to be implemented - esp for date slider)'

      it 'handles yyth century dates' do
        m = "<mods #{ns_decl}><originInfo>
              <dateIssued>19th century</dateIssued>
            </originInfo></mods>"
        sdb = sdb_for_mods(m)
        doc_hash = sdb.doc_hash_from_mods
        expect(doc_hash[:pub_date]).to eq('19th century')  # deprecated due to new pub_year_ fields
        expect(doc_hash[:pub_date_sort]).to eq('1800') # covered in pub_date_sort tests
        expect(doc_hash[:pub_year_tisim]).to eq('1800') # covered in pub_year_tisim tests
        expect(doc_hash[:publication_year_isi]).to eq('1800')
        expect(doc_hash[:imprint_display]).to eq('19th century') # covered in imprint_display tests
      end

      it 'works on explicit 3 digit dates' do
        m = "<mods #{ns_decl}><originInfo>
              <dateIssued>966</dateIssued>
            </originInfo></mods>"
        sdb = sdb_for_mods(m)
        doc_hash = sdb.doc_hash_from_mods
        expect(doc_hash[:pub_date_sort]).to eq('0966') # covered in pub_date_sort tests
        expect(doc_hash[:pub_date]).to eq('966')  # deprecated due to new pub_year_ fields
        expect(doc_hash[:pub_year_tisim]).to eq('0966') # covered in pub_year_tisim tests
        expect(doc_hash[:publication_year_isi]).to eq('0966')
        expect(doc_hash[:imprint_display]).to eq('966') # covered in imprint_display tests
      end
      it 'works on 3 digit century dates' do
        m = "<mods #{ns_decl}><originInfo>
              <dateIssued>9th century</dateIssued>
            </originInfo></mods>"
        sdb = sdb_for_mods(m)
        doc_hash = sdb.doc_hash_from_mods
        expect(doc_hash[:pub_date_sort]).to eq('0800') # covered in pub_date_sort tests
        expect(doc_hash[:pub_year_tisim]).to eq('0800') # covered in pub_year_tisim tests
        expect(doc_hash[:pub_date]).to eq('9th century') # deprecated due to new pub_year_ fields
        expect(doc_hash[:publication_year_isi]).to eq('0800')
        expect(doc_hash[:imprint_display]).to eq('9th century') # covered in imprint_display tests
      end
      it 'works on 3 digit BC dates' do
        m = "<mods #{ns_decl}><originInfo>
              <dateCreated>300 B.C.</dateCreated>
            </originInfo></mods>"
        sdb = sdb_for_mods(m)
        doc_hash = sdb.doc_hash_from_mods
        expect(doc_hash[:pub_date_sort]).to eq('-700') # covered in pub_date_sort tests
        expect(doc_hash[:pub_year_tisim]).to be_nil # covered in pub_year_tisim tests
        expect(doc_hash[:pub_date]).to eq('300 B.C.') # deprecated due to new pub_year_ fields
        expect(doc_hash[:imprint_display]).to eq('300 B.C.') # covered in imprint_display tests
        # doc_hash[:creation_year_isi].should =='-300'
      end
    end # difficult pub dates
  end # publication date fields

  context 'imprint_display' do
    # FIXME:  it should be using a method returning a better string than just year
    it 'imprint_display calls deprecated Stanford::Mods::Record instance pub_date_display' do
      expect(sdb.smods_rec).to receive(:pub_date_display)
      sdb.doc_hash_from_mods[:imprint_display]
    end
    it_behaves_like "expected", :imprint_display, '1945', '1945'
    it_behaves_like "expected", :imprint_display, '945', '945'
    it_behaves_like "expected", :imprint_display, '16--', '16--'
    it_behaves_like "expected", :imprint_display, '9--', '9--'
    it_behaves_like "expected", :imprint_display, '19th century', '19th century'
    it_behaves_like "expected", :imprint_display, '9th century', '9th century'
    it_behaves_like "expected", :imprint_display, 'blah June 4, 1594; blah 1596', 'blah June 4, 1594; blah 1596'
    it_behaves_like "expected", :imprint_display, 'Aug. 3rd, 1886', 'Aug. 3rd, 1886'
    it_behaves_like "expected", :imprint_display, 'Aug. 3rd, [18]86?', 'Aug. 3rd, [18]86?'
    it_behaves_like "expected", :imprint_display, 'early 1890s', 'early 1890s'
    it_behaves_like "expected", :imprint_display, '1865-6', '1865-6'
  end
end
