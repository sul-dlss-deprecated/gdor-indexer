require 'spec_helper'

describe GDor::Indexer::SolrDocBuilder do
  before(:all) do
    @fake_druid = 'oo000oo0000'
    @ns_decl = "xmlns='#{Mods::MODS_NS}'"
    @mods_xml = "<mods #{@ns_decl}><note>SolrDocBuilder test</note></mods>"
    @ng_mods_xml = Nokogiri::XML(@mods_xml)
  end

  let :logger do
    Logger.new(StringIO.new)
  end

  def sdb_for_data(mods, pub_xml)
    resource = Harvestdor::Indexer::Resource.new(double, @fake_druid)
    allow(resource).to receive(:mods).and_return(Nokogiri::XML(mods))
    allow(resource).to receive(:public_xml).and_return(Nokogiri::XML(pub_xml))
    GDor::Indexer::SolrDocBuilder.new(resource, logger)
  end

  # NOTE:
  # "Doubles, stubs, and message expectations are all cleaned out after each example."
  # per https://www.relishapp.com/rspec/rspec-mocks/docs/scope

  context 'doc_hash' do
    before(:all) do
      cmd_xml = "<contentMetadata type='image' objectId='#{@fake_druid}'></contentMetadata>"
      @pub_xml = "<publicObject id='druid#{@fake_druid}'>#{cmd_xml}</publicObject>"
    end
    let :doc_hash do
      sdb_for_data(@mods_xml, @pub_xml).doc_hash
    end
    before(:each) do
      @doc_hash = doc_hash
    end
    it 'id field should be set to druid for non-merged record' do
      expect(@doc_hash[:id]).to eq(@fake_druid)
    end
    it 'does not have the gdor fields set in indexer.rb' do
      expect(@doc_hash).to_not have_key(:druid)
      expect(@doc_hash).to_not have_key(:access_facet)
      expect(@doc_hash).to_not have_key(:url_fulltext)
      expect(@doc_hash).to_not have_key(:display_type)
      expect(@doc_hash).to_not have_key(:file_id)
    end
    it 'has the full MODS in the modsxml field for non-merged record' do
      expect(@doc_hash[:modsxml]).to be_equivalent_to @mods_xml
    end
  end # doc hash

  context '#catkey' do
    before(:all) do
      @identity_md_start = "<publicObject><identityMetadata objectId='#{@fake_druid}'>"
      @identity_md_end = '</identityMetadata></publicObject>'
      @empty_id_md = "#{@identity_md_start}#{@identity_md_end}"
      @barcode_id_md = "#{@identity_md_start}<otherId name=\"barcode\">666</otherId>#{@identity_md_end}"
    end
    it 'is nil if there is no indication of catkey in identityMetadata' do
      sdb = sdb_for_data(@mods_xml, @empty_id_md)
      expect(sdb.catkey).to be_nil
    end
    it 'takes a catkey in identityMetadata/otherId with name attribute of catkey' do
      pub_xml = "#{@identity_md_start}<otherId name=\"catkey\">12345</otherId>#{@identity_md_end}"
      sdb = sdb_for_data(@mods_xml, pub_xml)
      expect(sdb.catkey).to eq('12345')
    end
    it 'is nil if there is no indication of catkey in identityMetadata even if there is a catkey in the mods' do
      m = "<mods #{@ns_decl}><recordInfo>
        <recordIdentifier source=\"SIRSI\">a6780453</recordIdentifier>
      </recordInfo></mods>"
      sdb = sdb_for_data(@mods_xml, @empty_id_md)
      expect(sdb.catkey).to be_nil
    end
    it 'logs an error when there is identityMetadata/otherId with name attribute of barcode but there is no catkey in mods' do
      sdb = sdb_for_data(@mods_xml, @barcode_id_md)
      expect(logger).to receive(:error).with(/#{@fake_druid} has barcode .* in identityMetadata but no SIRSI catkey in mods/)
      sdb.catkey
    end

    context 'catkey from mods' do
      it 'looks for catkey in mods if identityMetadata/otherId with name attribute of barcode is found' do
        sdb = sdb_for_data(@mods_xml, @barcode_id_md)
        smr = sdb.smods_rec
        expect(smr).to receive(:record_info).and_call_original # this is as close as I can figure to @smods_rec.record_info.recordIdentifier
        sdb.catkey
      end
      it 'is nil if there is no catkey in the mods' do
        m = "<mods #{@ns_decl}><recordInfo>
          <descriptionStandard>dacs</descriptionStandard>
        </recordInfo></mods>"
        sdb = sdb_for_data(m, @barcode_id_md)

        expect(sdb.catkey).to be_nil
      end
      it 'populated when source attribute is SIRSI' do
        m = "<mods #{@ns_decl}><recordInfo>
          <recordIdentifier source=\"SIRSI\">a6780453</recordIdentifier>
        </recordInfo></mods>"
        sdb = sdb_for_data(m, @barcode_id_md)
        expect(sdb.catkey).not_to be_nil
      end
      it 'not populated when source attribute is not SIRSI' do
        m = "<mods #{@ns_decl}><recordInfo>
          <recordIdentifier source=\"FOO\">a6780453</recordIdentifier>
        </recordInfo></mods>"
        sdb = sdb_for_data(m, @barcode_id_md)
        expect(sdb.catkey).to be_nil
      end
      it 'removes the a at the beginning of the catkey' do
        m = "<mods #{@ns_decl}><recordInfo>
          <recordIdentifier source=\"SIRSI\">a6780453</recordIdentifier>
        </recordInfo></mods>"
        sdb = sdb_for_data(m, @barcode_id_md)
        expect(sdb.catkey).to eq('6780453')
      end
    end
  end # #catkey

  context 'using Harvestdor::Client' do
    context '#smods_rec (called in initialize method)' do
      it 'returns Stanford::Mods::Record object' do
        sdb = sdb_for_data(@mods_xml, nil)
        expect(sdb.smods_rec).to be_an_instance_of(Stanford::Mods::Record)
      end
    end
  end # context using Harvestdor::Client
end
