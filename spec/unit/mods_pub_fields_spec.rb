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

  context 'publication date fields' do
    let(:sdb) { sdb_for_mods(mods_xml) }

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
      expect(doc_hash[:pub_year_tisim]).to eq('1800') # date slider
      expect(doc_hash[:imprint_display]).to eq('blah blah 19th century blah blah')
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
      it 'yyyy for yyyy dates' do
        m = mods_origin_info_start_str +
              "<dateIssued>1945</dateIssued>" +
            mods_origin_info_end_str
        sdb = sdb_for_mods(m)
        expect(sdb.doc_hash_from_mods[:pub_date_sort]).to eq('1945')
      end
      it '0yyy for yyy dates' do
        m = mods_origin_info_start_str +
              "<dateIssued>945</dateIssued>" +
            mods_origin_info_end_str
        sdb = sdb_for_mods(m)
        expect(sdb.doc_hash_from_mods[:pub_date_sort]).to eq('0945')
      end
      it 'yy00 for yy-- dates' do
        m = mods_origin_info_start_str +
              "<dateIssued>16--</dateIssued>"
            mods_origin_info_end_str
        sdb = sdb_for_mods(m)
        expect(sdb.doc_hash_from_mods[:pub_date_sort]).to eq('1600')
      end
      it '0y00 for y-- dates' do
        m = mods_origin_info_start_str +
              "<dateIssued>9--</dateIssued>" +
            mods_origin_info_end_str
        sdb = sdb_for_mods(m)
        expect(sdb.doc_hash_from_mods[:pub_date_sort]).to eq('0900')
      end
      it 'yy00 for yyth century dates' do
        m = mods_origin_info_start_str +
              "<dateIssued>19th century</dateIssued>" +
            mods_origin_info_end_str
        sdb = sdb_for_mods(m)
        expect(sdb.doc_hash_from_mods[:pub_date_sort]).to eq('1800')
      end
      it '0y00 for yth century dates' do
        m = mods_origin_info_start_str +
              "<dateIssued>9th century</dateIssued>" +
            mods_origin_info_end_str
        sdb = sdb_for_mods(m)
        expect(sdb.doc_hash_from_mods[:pub_date_sort]).to eq('0800')
      end
      it '-(1000 - |yyy|) for BC dates' do
        m = mods_origin_info_start_str +
              "<dateCreated>300 B.C.</dateCreated>" +
            mods_origin_info_end_str
        sdb = sdb_for_mods(m)
        expect(sdb.doc_hash_from_mods[:pub_date_sort]).to eq('-700')
      end
    end # pub_date_sort

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
        it 'yyyy for yyyy dates' do
          m = "<mods #{ns_decl}><originInfo><dateIssued>1945</dateIssued></originInfo></mods>"
          sdb = sdb_for_mods(m)
          expect(sdb.doc_hash_from_mods[field_sym]).to eq('1945')
        end
        it 'yyy for yyy dates' do
          m = "<mods #{ns_decl}><originInfo><dateIssued>945</dateIssued></originInfo></mods>"
          sdb = sdb_for_mods(m)
          expect(sdb.doc_hash_from_mods[field_sym]).to eq('945')
        end
        it '(yy+1)th century for yy-- dates' do
          m = "<mods #{ns_decl}><originInfo><dateIssued>16--</dateIssued></originInfo></mods>"
          sdb = sdb_for_mods(m)
          expect(sdb.doc_hash_from_mods[field_sym]).to eq('17th century')
        end
        it '(y+1)th century for y-- dates' do
          m = "<mods #{ns_decl}><originInfo><dateIssued>8--</dateIssued></originInfo></mods>"
          sdb = sdb_for_mods(m)
          expect(sdb.doc_hash_from_mods[field_sym]).to eq('9th century')
        end
        it 'yyth century as is' do
          m = mods_origin_info_start_str +
                "<dateIssued>19th century</dateIssued>" +
              mods_origin_info_end_str
          sdb = sdb_for_mods(m)
          expect(sdb.doc_hash_from_mods[field_sym]).to eq('19th century')
        end
        it 'yth century as is' do
          m = mods_origin_info_start_str +
                "<dateIssued>9th century</dateIssued>" +
              mods_origin_info_end_str
          sdb = sdb_for_mods(m)
          expect(sdb.doc_hash_from_mods[field_sym]).to eq('9th century')
        end
        it 'BC dates as is' do
          m = mods_origin_info_start_str +
                "<dateCreated>300 B.C.</dateCreated>" +
              mods_origin_info_end_str
          sdb = sdb_for_mods(m)
          expect(sdb.doc_hash_from_mods[field_sym]).to eq('300 B.C.')
        end
      end
      it_behaves_like "single pub year facet", :pub_year_no_approx_isi
      it_behaves_like "single pub year facet", :pub_year_w_approx_isi
    end

    context 'pub_year_tisim for date slider' do
      it 'takes single dateCreated' do
        m = mods_origin_info_start_str +
              "<dateCreated>1904</dateCreated>" +
            mods_origin_info_end_str
        sdb = sdb_for_mods(m)
        expect(sdb.doc_hash_from_mods[:pub_year_tisim]).to eq('1904')
      end
      it 'takes first yyyy in string' do
        m = mods_origin_info_start_str +
              "<dateCreated>Text dated June 4, 1594; miniatures added by 1596</dateCreated>" +
            mods_origin_info_end_str
        sdb = sdb_for_mods(m)
        expect(sdb.doc_hash_from_mods[:pub_year_tisim]).to eq('1594')
      end
      it 'finds year in an expanded English form' do
        m = mods_origin_info_start_str +
              "<dateCreated>Aug. 3rd, 1886</dateCreated>" +
            mods_origin_info_end_str
       sdb = sdb_for_mods(m)
        expect(sdb.doc_hash_from_mods[:pub_year_tisim]).to eq('1886')
      end
      it 'removes question marks and brackets' do
        m = mods_origin_info_start_str +
             " <dateCreated>Aug. 3rd, [18]86?</dateCreated>" +
          mods_origin_info_end_str
        sdb = sdb_for_mods(m)
        expect(sdb.doc_hash_from_mods[:pub_year_tisim]).to eq('1886')
      end
      it 'ignores an s after the decade' do
        m = mods_origin_info_start_str +
              "<dateCreated>early 1890s</dateCreated>" +
          mods_origin_info_end_str
        sdb = sdb_for_mods(m)
        expect(sdb.doc_hash_from_mods[:pub_year_tisim]).to eq('1890')
      end
      it 'takes first year from hyphenated range (for now)' do
        m = mods_origin_info_start_str +
              "<dateIssued>1865-6</dateIssued>" +
          mods_origin_info_end_str
        sdb = sdb_for_mods(m)
        doc_hash = sdb.doc_hash_from_mods
        expect(doc_hash[:pub_year_tisim]).to eq('1865')
      end
    end # pub_year_tisim

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
        expect(doc_hash[:pub_year_tisim]).to eq('1800')
        expect(doc_hash[:publication_year_isi]).to eq('1800')
        expect(doc_hash[:imprint_display]).to eq('19th century')
      end

      it 'works on explicit 3 digit dates' do
        m = "<mods #{ns_decl}><originInfo>
              <dateIssued>966</dateIssued>
            </originInfo></mods>"
        sdb = sdb_for_mods(m)
        doc_hash = sdb.doc_hash_from_mods
        expect(doc_hash[:pub_date_sort]).to eq('0966') # covered in pub_date_sort tests
        expect(doc_hash[:pub_date]).to eq('966')  # deprecated due to new pub_year_ fields
        expect(doc_hash[:pub_year_tisim]).to eq('0966')
        expect(doc_hash[:publication_year_isi]).to eq('0966')
        expect(doc_hash[:imprint_display]).to eq('966')
      end
      it 'works on 3 digit century dates' do
        m = "<mods #{ns_decl}><originInfo>
              <dateIssued>9th century</dateIssued>
            </originInfo></mods>"
        sdb = sdb_for_mods(m)
        doc_hash = sdb.doc_hash_from_mods
        expect(doc_hash[:pub_date_sort]).to eq('0800') # covered in pub_date_sort tests
        expect(doc_hash[:pub_year_tisim]).to eq('0800')
        expect(doc_hash[:pub_date]).to eq('9th century') # deprecated due to new pub_year_ fields
        expect(doc_hash[:publication_year_isi]).to eq('0800')
        expect(doc_hash[:imprint_display]).to eq('9th century')
      end
      it 'works on 3 digit BC dates' do
        m = "<mods #{ns_decl}><originInfo>
              <dateCreated>300 B.C.</dateCreated>
            </originInfo></mods>"
        sdb = sdb_for_mods(m)
        doc_hash = sdb.doc_hash_from_mods
        expect(doc_hash[:pub_date_sort]).to eq('-700') # covered in pub_date_sort tests
        expect(doc_hash[:pub_year_tisim]).to be_nil
        expect(doc_hash[:pub_date]).to eq('300 B.C.') # deprecated due to new pub_year_ fields
        expect(doc_hash[:imprint_display]).to eq('300 B.C.')
        # doc_hash[:creation_year_isi].should =='-300'
      end
    end # difficult pub dates
  end # publication date fields
end
