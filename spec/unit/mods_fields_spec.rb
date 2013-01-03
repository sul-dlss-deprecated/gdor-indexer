require 'spec_helper'
# FIXME:  should all these be required, chain-wise, in Indexer class?
require 'mods_fields'

describe 'mods_fields mixin for SolrDocBuilder class' do

  before(:all) do
    @fake_druid = 'oo000oo0000'
    @ns_decl = "xmlns='#{Mods::MODS_NS}'"
  end
  
  before(:each) do
    @hdor_client = double()
    @hdor_client.stub(:public_xml).with(@fake_druid).and_return(nil)
  end

  context "sw subject methods" do
    before(:all) do
      @genre = 'genre top level'
      @cart_coord = '6 00 S, 71 30 E'
      @s_genre = 'genre in subject'
      @geo = 'Somewhere'
      @geo_code = 'us'
      @hier_geo_country = 'France'
      @s_name = 'name in subject'
      @occupation = 'worker bee'
      @temporal = 'temporal'
      @s_title = 'title in subject'
      @topic = 'topic'
      m = "<mods #{@ns_decl}>
        <genre>#{@genre}</genre>
        <subject><cartographics><coordinates>#{@cart_coord}</coordinates></cartographics></subject>
        <subject><genre>#{@s_genre}</genre></subject>
        <subject><geographic>#{@geo}</geographic></subject>
        <subject><geographicCode authority='iso3166'>#{@geo_code}</geographicCode></subject>
        <subject><hierarchicalGeographic><country>#{@hier_geo_country}</country></hierarchicalGeographic></subject>
        <subject><name><namePart>#{@s_name}</namePart></name></subject>
        <subject><occupation>#{@occupation}</occupation></subject>
        <subject><temporal>#{@temporal}</temporal></subject>
        <subject><titleInfo><title>#{@s_title}</title></titleInfo></subject>
        <subject><topic>#{@topic}</topic></subject>      
      </mods>"
      @ng_mods = Nokogiri::XML(m)
      m_no_subject = "<mods #{@ns_decl}><note>notit</note></mods>"
      @ng_mods_no_subject = Nokogiri::XML(m_no_subject)
    end
    before(:each) do
      @hdor_client.stub(:mods).with(@fake_druid).and_return(@ng_mods)      
      @sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(STDOUT))
    end
    
    context "topic_search" do
      it "should be nil if there are no values in the MODS" do
        @hdor_client.stub(:mods).with(@fake_druid).and_return(@ng_mods_no_subject)
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(STDOUT))
        sdb.topic_search.should == nil
      end
      it "should contain subject <topic> subelement data" do
        @sdb.topic_search.should include(@topic)
      end
      it "should contain <genre> element data" do
        @sdb.topic_search.should include(@genre)
      end
      it "should not contain other subject element data" do
        @sdb.topic_search.should_not include(@cart_coord)
        @sdb.topic_search.should_not include(@s_genre)
        @sdb.topic_search.should_not include(@geo)
        @sdb.topic_search.should_not include(@geo_code)
        @sdb.topic_search.should_not include(@hier_geo_country)
        @sdb.topic_search.should_not include(@s_name)
        @sdb.topic_search.should_not include(@occupation)
        @sdb.topic_search.should_not include(@temporal)
        @sdb.topic_search.should_not include(@s_title)
      end
      it "should not be nil if there are only subject/topic elements (no <genre>)" do
        m = "<mods #{@ns_decl}><subject><topic>#{@topic}</topic></subject></mods>"
        @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(STDOUT))
        sdb.topic_search.should == [@topic]
      end
      it "should not be nil if there are only <genre> elements (no subject/topic elements)" do
        m = "<mods #{@ns_decl}><genre>#{@genre}</genre></mods>"
        @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(STDOUT))
        sdb.topic_search.should == [@genre]
      end
      context "topic subelement" do
        it "should have a separate value for each topic element" do
          m = "<mods #{@ns_decl}>
                <subject>
                  <topic>first</topic>
                  <topic>second</topic>
                </subject>
                <subject><topic>third</topic></subject>
              </mods>"
          @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
          sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(STDOUT))
          sdb.topic_search.should == ['first', 'second', 'third']
        end
        it "should be nil if there are only empty values in the MODS" do
          m = "<mods #{@ns_decl}><subject><topic/></subject><note>notit</note></mods>"
          @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
          sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(STDOUT))
          sdb.topic_search.should == nil
        end
      end
    end # topic_search
    
    context "subject_other_subvy_search" do
      it "should be nil if there are no values in the MODS" do
        @hdor_client.stub(:mods).with(@fake_druid).and_return(@ng_mods_no_subject)
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(STDOUT))
        sdb.subject_other_subvy_search.should == nil
      end
      it "should contain subject <temporal> subelement data" do
        @sdb.subject_other_subvy_search.should include(@temporal)
      end
      it "should contain subject <genre> SUBelement data" do
        @sdb.subject_other_subvy_search.should include(@s_genre)
      end
      it "should not contain other subject element data" do
        @sdb.subject_other_subvy_search.should_not include(@genre)
        @sdb.subject_other_subvy_search.should_not include(@cart_coord)
        @sdb.subject_other_subvy_search.should_not include(@geo)
        @sdb.subject_other_subvy_search.should_not include(@geo_code)
        @sdb.subject_other_subvy_search.should_not include(@hier_geo_country)
        @sdb.subject_other_subvy_search.should_not include(@s_name)
        @sdb.subject_other_subvy_search.should_not include(@occupation)
        @sdb.subject_other_subvy_search.should_not include(@topic)
        @sdb.subject_other_subvy_search.should_not include(@s_title)
      end
      it "should not be nil if there are only subject/temporal elements (no subject/genre)" do
        m = "<mods #{@ns_decl}><subject><temporal>#{@temporal}</temporal></subject></mods>"
        @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(STDOUT))
        sdb.subject_other_subvy_search.should == [@temporal]
      end
      it "should not be nil if there are only subject/genre elements (no subject/temporal)" do
        m = "<mods #{@ns_decl}><subject><genre>#{@s_genre}</genre></subject></mods>"
        @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(STDOUT))
        sdb.subject_other_subvy_search.should == [@s_genre]
      end
      context "temporal subelement" do
        it "should have a separate value for each temporal element" do
          m = "<mods #{@ns_decl}>
                <subject>
                  <temporal>1890-1910</temporal>
                	<temporal>20th century</temporal>
                </subject>
                <subject><temporal>another</temporal></subject>
              </mods>"
          @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
          sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(STDOUT))
          sdb.subject_other_subvy_search.should == ['1890-1910', '20th century', 'another']
        end
        it "should log an info message when it encounters an encoding it doesn't translate" do
          m = "<mods #{@ns_decl}><subject><temporal encoding='iso8601'>197505</temporal></subject></mods>"
          @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
          sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(STDOUT))
          sdb.logger.should_receive(:info).with(/#{@fake_druid} has subject temporal element with untranslated encoding: <temporal encoding=.*>197505<\/temporal>/)
          sdb.subject_other_subvy_search
        end
        it "should be nil if there are only empty values in the MODS" do
          m = "<mods #{@ns_decl}><subject><temporal/></subject><note>notit</note></mods>"
          @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
          sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(STDOUT))
          sdb.subject_other_subvy_search.should == nil
        end
      end
      context "genre subelement" do
        it "should have a separate value for each genre element" do
          m = "<mods #{@ns_decl}>
                <subject>
                  <genre>first</genre>
                  <genre>second</genre>
                </subject>
                <subject><genre>third</genre></subject>
              </mods>"
          @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
          sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(STDOUT))
          sdb.subject_other_subvy_search.should == ['first', 'second', 'third']
        end
        it "should be nil if there are only empty values in the MODS" do
          m = "<mods #{@ns_decl}><subject><genre/></subject><note>notit</note></mods>"
          @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
          sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(STDOUT))
          sdb.subject_other_subvy_search.should == nil
        end
      end
    end # subject_other_subvy_search


    context "topic" do
      before(:all) do
        m = "<mods #{@ns_decl}>
        <subject authority='lcsh'>
          <topic>Real property</topic>
          <geographic>Mississippi</geographic>
          <geographic>Tippah County</geographic>
          <genre>Maps</genre>
        </subject>
        <subject authority='lcsh'>
          <topic>Musicology</topic>
          <topic>Data processing</topic>
          <genre>Periodicals</genre>
        </subject>
        <subject authority='lcsh'>
          <topic>Real property--Mississippi--Tippah County--Maps</topic>
        </subject>
        <subject authority='lcshac'>
          <topic>Iron founding</topic>
        </subject>
        <subject authority='lctgm'>
        	<topic>Educational buildings</topic>
        	<geographic>Washington (D.C.)</geographic>
        	<temporal>1890-1910</temporal>
        </subject>
        <subject>
          <occupation>Migrant laborers</occupation>
          <genre>School district case files</genre>
        </subject>
        <subject authority='ericd'>
        	<topic>Career Exploration</topic>
        </subject>
        <subject authority='rvm'>
        	<topic>Eglise catholique</topic>
        	<topic>Histoire</topic>
        	<temporal>20e siecle</temporal>
        </subject>
        <subject>
        	<topic>Learning disabilities</topic>
        </subject>
        <subject>
        	<name type='personal' authority='naf'>
      	  	<namePart>Woolf, Virginia</namePart>
      	  	<namePart type='date'>1882-1941</namePart>
        	</name>
        </subject>
        <subject authority='lcsh'>
         	<name>
         	  <namePart>Garcia Lorca, Federico</namePart>
          	<namePart type='date'>1898-1936</namePart>
          </name>
        </subject>
        <subject>
        	<occupation>Anthropologists</occupation>
        </subject>
        <subject>
        	<titleInfo type='uniform' authority='naf'>
      	  	<title>Missale Carnotense</title>
        	</titleInfo>
        </subject>
        <subject>
        	<temporal encoding='iso8601'>197505</temporal>
        </subject>
        </mods>"
      end
      it "should contain subject/topic" do
        pending "to be implemented"
      end
      it "should contain genre" do
        pending "to be implemented"
      end
      
    end # topic
    
    context "geographic" do
      before(:all) do
        m = "<mods #{@ns_decl}>
        <subject authority='lcsh'>
          <topic>Real property</topic>
          <geographic>Mississippi</geographic>
          <geographic>Tippah County</geographic>
          <genre>Maps</genre>
        </subject>
        <subject authority='lctgm'>
        	<topic>Educational buildings</topic>
        	<geographic>Washington (D.C.)</geographic>
        	<temporal>1890-1910</temporal>
        </subject>
        <subject>
          <geographicCode authority='marcgac'>n-us-md</geographicCode>
        </subject>
        <subject>
        	<geographicCode authority='iso3166'>us</geographicCode>
        </subject>
        <subject>
          <hierarchicalGeographic>
          	<country>Canada</country>
          	<province>British Columbia</province>
          	<city>Vancouver</city>
          </hierarchicalGeographic>
        </subject>
        <subject>
        	<hierarchicalGeographic>
      	  	<country>France</country>
      	  	<state>Doubs</state>
        	</hierarchicalGeographic>
        </subject>
        <subject>
        	<hierarchicalGeographic>
      	  	<country>France</country>
      	  	<region>Franche Comte</region>
        	</hierarchicalGeographic>
        </subject>        
        <subject>
        	<hierarchicalGeographic>
      	  	<country>United States</country>
      	  	<state>Kansas</state>
      	  	<county>Butler</county>
      	  	<city>Augusta</city>
        	</hierarchicalGeographic>
        </subject>
        <subject>
        	<hierarchicalGeographic>
      	  	<area>Intercontinental areas (Western Hemisphere)</area>
        	</hierarchicalGeographic>
        </subject>
        </mods>"
      end
      it "should include plain geographic" do
        pending "to be implemented"
      end
      it "should include geographicCode info" do
        pending "to be implemented"
      end
      it "should include hierarchicalGeographic" do
        pending "to be implemented"
      end
      context "hierarchicalGeographic" do
        it "should do something sensible with the hierarchical information (sort of lcsh-ish?)" do
          pending "to be implemented"
        end
      end
      context "geographicCode" do
        it "should translate marcgac codes" do
          pending "to be implemented"
        end
        it "should translate marccountry codes" do
          pending "to be implemented"
        end
        it "should translate iso3166 codes" do
          pending "to be implemented"
        end
      end
    end # geographic
    context "time" do
      before(:all) do
        m = "<mods #{@ns_decl}>
        <subject authority='lctgm'>
        	<topic>Educational buildings</topic>
        	<geographic>Washington (D.C.)</geographic>
        	<temporal>1890-1910</temporal>
        </subject>
        <subject authority='rvm'>
        	<topic>Eglise catholique</topic>
        	<topic>Histoire</topic>
        	<temporal>20e siecle</temporal>
        </subject>
        <subject>
        	<temporal encoding='iso8601'>197505</temporal>
        </subject>
        <subject authority='lcsh'>
        	<topic>Bluegrass music</topic>
        	<temporal>1971-1980</temporal>
        </subject>
        </mods>"
      end
    end # time
    context "name" do
      
    end # context name
    context "title" do
      
    end # context title
  end # context sw subject methods
  
  
end