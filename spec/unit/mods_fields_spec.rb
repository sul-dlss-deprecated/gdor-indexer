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
    end
    before(:each) do
      @hdor_client.stub(:mods).with(@fake_druid).and_return(@ng_mods)      
      @sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, nil)
    end
    
    context "topic_search" do
      it "should contain subject <topic> element data" do
        pending "to be implemented"
        @sdb.topic_search.should include(@topic)
      end
      it "should contain <genre> element data" do
        pending "to be implemented"
        @sdb.topic_search.should include(@genre)
      end
      it "should not contain subject <cartographics> element data" do
        pending "to be implemented"
      end
      it "should not contain subject <geographic> element data" do
        pending "to be implemented"
      end
      it "should not contain subject <geographicCode> element data" do
        pending "to be implemented"
      end
      it "should not contain subject <hierarcicalGeographic> element data" do
        pending "to be implemented"
      end
      it "should not contain *subject* <name> element data" do
        pending "to be implemented"
      end
      it "should not contain subject <occupation> element data" do
        pending "to be implemented"
      end
      it "should not contain subject <temporal> element data" do
        pending "to be implemented"
      end
      it "should not contain *subject* <titleInfo> element data" do
        pending "to be implemented"
      end
      # more refinements of genre elements (with authorities, etc?)
      # more refinements of topic elements ??
    end
    
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
  
  context "using MODS nom terminology and Stanford::Mods::Record methods" do
    before(:all) do
      m = "<mods #{@ns_decl}>
        <abstract>single</abstract>
        <genre></genre>
        <note>mult1</note>
        <note>mult2</note>
      </mods>"
      @ng_mods = Nokogiri::XML(m)
    end
    before(:each) do
      @hdor_client.stub(:mods).with(@fake_druid).and_return(@ng_mods)
      @logger = Logger.new(STDOUT)
      @sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, @logger)
    end
    
    context "mods_value (single value)" do
      it "should return nil if there are no such values in the MODS" do
        @sdb.send(:mods_value, :identifier).should == nil
      end
      it "should return nil if there are only empty values in the MODS" do
        @sdb.send(:mods_value, :genre).should == nil
      end
      it "should log a message for a MethodMissing error" do
        @logger.should_receive(:error).with("#{@fake_druid} tried to get mods_value for unknown message: not_there")
        @sdb.send(:mods_value, :not_there).should == nil
      end
      it "should return a String for a single value" do
        @sdb.send(:mods_value, :abstract).should == 'single'
      end
      it "should return a String containing all values, separated by space, for multiple values in the MODS record" do
        @sdb.send(:mods_value, :note).should == 'mult1 mult2'
      end
    end

    context "mods_values (multiple values)" do
      it "should return nil if there are no such values in the MODS" do
        @sdb.send(:mods_values, :identifier).should == nil
      end
      it "should return nil if there are only empty values in the MODS" do
        @sdb.send(:mods_values, :genre).should == nil
      end
      it "should log a message for a MethodMissing error" do
        @logger.should_receive(:error).with("#{@fake_druid} tried to get mods_values for unknown message: not_there")
        @sdb.send(:mods_values, :not_there).should == nil
      end
      it "should return an array of size one for a single value" do
        @sdb.send(:mods_values, :abstract).should == ['single']
      end
      it "should return an array of values for multiple values" do
        @sdb.send(:mods_values, :note).should == ['mult1', 'mult2']
      end
    end
    
  end # using MODS nom terminology and Stanford::Mods::Record methods  
  
end