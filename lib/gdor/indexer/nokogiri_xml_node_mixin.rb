module Nokogiri
  module XML
    # Monkey patch for Nokogiri to cache xpath contexts and make things faster under jRuby
    class Node
      @context = nil

      def xpath(*paths)
        return NodeSet.new(document) unless document

        paths, handler, ns, binds = extract_params(paths)

        sets = paths.map do |path|
          # if self.contexts[path]
          #  ctx = self.contexts[path]
          # else
          if @context
            ctx = @context
          else
            ctx = XPathContext.new(self)
            @context = ctx
          end
          ctx.register_namespaces(ns)
          path = path.gsub(/xmlns:/, ' :') unless Nokogiri.uses_libxml?
          binds.each do |key, value|
            ctx.register_variable key.to_s, value
          end if binds
          ctx.evaluate(path, handler)
        end

        return sets.first if sets.length == 1

        NodeSet.new(document) do |combined|
          sets.each do |set|
            set.each do |node|
              combined << node
            end
          end
        end
      end # def xpath
    end # class Node
  end # module XML
end # module Nokogiri
