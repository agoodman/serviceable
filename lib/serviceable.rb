class Hash
  def &(other)
    reject {|k,v| !(other.include?(k) && ([v]&[other[k]]).any?)}
  end
  def compact
    reject {|k,v| k.nil? || v.nil?}
  end
end

module Serviceable
  
  def self.included(base)
    base.extend(ClassMethods)
  end
  
  module ClassMethods
    
    # Serviceable Usage
    #
    # Controller:
    # class PostsController
    #   acts_as_service :post
    # end
    #
    def acts_as_service(object,defaults={})

      before_filter :assign_new_instance, only: :create
      before_filter :did_assign_new_instance, only: :create
      before_filter :assign_existing_instance, only: [ :show, :update, :destroy ]
      before_filter :did_assign_existing_instance, only: [ :show, :update ]
      before_filter :assign_collection, only: [ :index, :count ]
      before_filter :did_assign_collection, only: [ :index, :count ]
      
      define_method("index") do
        respond_to do |format|
          format.json { render json: @collection.to_json(merge_options(defaults[:index])) }
          format.xml  { render xml: @collection.to_xml(merge_options(defaults[:index])) }
        end
      end
      
      define_method("count") do
        respond_to do |format|
          format.json { render json: @collection.count }
          format.xml { render xml: @collection.count }
        end
      end

      define_method("create") do
        respond_to do |format|
          if @instance.save
            format.json { render json: @instance, status: :created }
            format.xml  { render xml: @instance, status: :created }
          else
            format.json { render json: { errors: @instance.errors.full_messages }, status: :unprocessable_entity }
            format.xml  { render xml: { errors: @instance.errors.full_messages }, status: :unprocessable_entity }
          end
        end
      end

      define_method("show") do
        respond_to do |format|
          format.json { render json: @instance.to_json(merge_options(defaults[:show])) }
          format.xml  { render xml: @instance.to_xml(merge_options(defaults[:show])) }
        end
      end

      define_method("update") do
        respond_to do |format|
          if @instance.update_attributes(params[object])
            format.json { head :ok }
            format.xml  { head :ok }
          else
            format.json { render json: { errors: @instance.errors.full_messages }, status: :unprocessable_entity }
            format.xml  { render xml: { errors: @instance.errors.full_messages }, status: :unprocessable_entity }
          end
        end
      end

      define_method("destroy") do
        @instance.destroy

        respond_to do |format|
          format.json { head :no_content }
          format.xml  { head :no_content }
        end
      end
      
      define_method("describe") do
        details = {
          allowed_includes: force_array(defaults[:allowed_includes]),
          allowed_methods: force_array(defaults[:allowed_methods])
        }
        respond_to do |format|
          format.json { render json: details.to_json, status: :ok }
          format.xml { render xml: details.to_xml, status: :ok }
        end
      end

      # query string params can be given in the following formats:
      # only=field1,field2
      # except=field1,field2
      # include=assoc1
      # methods=my_helper
      # 
      # if an included association is present, only and except params can be nested
      # include[user][except]=encrypted_password
      # include[user][only][]=first_name&include[user][only][]=last_name
      # include[user][only]=first_name,last_name
      #
      # NOTE: includes and methods are not supported for nested associations
      #
      # options specified by the developer are considered mandatory and can not be
      # overridden by the client
      #
      # client may only use includes and methods that are explicitly enabled by
      # the developer
      define_method("merge_options") do |options={}|
        merged_options = {}
        for key in [:only, :except]
          opts = {key => params[key]} if params[key]
          merged_options = merged_options.merge(opts) if opts
        end
        requested_includes = hash_for(params[:includes])
        allowed_includes = hash_for(defaults[:allowed_includes])
        requested_includes = deep_sym(requested_includes)
        allowed_includes = deep_sym(allowed_includes)
        whitelisted_includes = {}
        requested_includes.keys.each do |k|
          if allowed_includes.keys.include?(k)
            values = requested_includes[k]
            opts = {}
            opts[:only] = values[:only] if values[:only]
            opts[:except] = values[:except] if values[:except]
            whitelisted_includes[k] = opts
          end
        end
        if options && options[:include]
          if options[:include].kind_of?(Hash) 
            mandatory_includes = options[:include]
          elsif options[:include].kind_of?(Array)
            mandatory_includes = Hash[options[:include].map {|e| [e,{}]}]
          else
            mandatory_includes = {options[:include] => {}}
          end
          whitelisted_includes = whitelisted_includes.merge(mandatory_includes)
        end
        merged_options = merged_options.merge({include: whitelisted_includes}) if whitelisted_includes.keys.any?

        requested_methods = array_for(params[:methods])
        allowed_methods = array_for(defaults[:allowed_methods])
        requested_methods = requested_methods.map(&:to_s).map(&:to_sym)
        allowed_methods = allowed_methods.map(&:to_s).map(&:to_sym)
        whitelisted_methods = requested_methods & allowed_methods
        if options && options[:methods]
          mandatory_methods = array_for(options[:methods])
          whitelisted_methods = whitelisted_methods + mandatory_methods
        end
        merged_options = merged_options.merge({methods: whitelisted_methods}) if whitelisted_methods.any?
        merged_options = deep_split(merged_options.compact)
        return merged_options
      end
      
      define_method("assign_existing_instance") do
        @instance = object.to_s.camelize.constantize.scoped
        if params[:include].kind_of?(Hash)
          @instance = @instance.includes(params[:include].keys)
        end
        if params[:include].kind_of?(String)
          @instance = @instance.includes(params[:include].split(",").map(&:to_sym))
        end
        @instance = @instance.find(params[:id])
      end
      
      define_method("did_assign_existing_instance") do
        # do nothing
      end
      
      define_method("assign_new_instance") do
        @instance = object.to_s.camelize.constantize.new(params[object])
      end
      
      define_method("did_assign_new_instance") do
        # do nothing
      end
      
      # query string params can be used to filter collections
      #
      # filters apply on associated collections using the following conventions:
      # where[user][category]=Expert
      # where[user][created_at][gt]=20130807T12:34:56.789Z
      #
      # filters can be constructed with AND and OR behavior
      # where[tags][id][in]=123,234,345  (OR)
      # where[tags][id]=123&where[tags][id]=234  (AND)
      define_method("assign_collection") do
        @collection = object.to_s.camelize.constantize.scoped
        if params[:include].kind_of?(Hash)
          for assoc in params[:include].keys
            @collection = @collection.includes(assoc.to_sym)
          end
        end
        if params[:include].kind_of?(String)
          @collection = @collection.includes(params[:include].split(",").map(&:to_sym))
        end
        for assoc in (params[:where].keys rescue [])
          attrs = params[:where][assoc]
          if attrs.kind_of?(Hash)
            for target_column in attrs.keys
              if attrs[target_column].kind_of?(String)
                if is_boolean_column?(target_column)
                  value = true if ['t','true','1','y','yes'].include?(attrs[target_column].to_s)
                  value = false if ['f','false','0','n','no'].include?(attrs[target_column].to_s)
                else
                  value = attrs[target_column]
                end
                @collection = @collection.where(assoc => { target_column => value })
              elsif attrs[target_column].kind_of?(Hash)
                for op in attrs[target_column].keys.map(&:to_sym)
                  value = is_time_column?(target_column) ? Time.parse(attrs[target_column][op]) : attrs[target_column][op]
                  unless assoc.to_sym==object.to_s.pluralize.to_sym
                    @collection = @collection.includes(assoc)
                  end
                  if op==:gt
                    @collection = @collection.where("#{assoc}.#{target_column} > ?",value)
                  elsif op==:lt
                    @collection = @collection.where("#{assoc}.#{target_column} < ?",value)
                  elsif op==:in
                    @collection = @collection.where("#{assoc}.#{target_column} IN (?)",value.split(','))
                  end
                end
              end  
            end
          else
            @collection = @collection.includes(assoc).where(assoc => attrs)
          end
        end
      end
      
      define_method("did_assign_collection") do
        # do nothing
      end
      
      define_method("array_for") do |obj|
        if obj.kind_of?(Hash)
          arr = obj.keys
        elsif obj.kind_of?(Array)
          arr = obj
        elsif obj.kind_of?(String)
          arr = obj.split(',')
        else
          arr = Array(obj)
        end
        arr.compact.uniq rescue []
      end
      
      # designed to traverse an entire hash, replacing delimited strings with arrays of symbols
      define_method("deep_split") do |hash={},pivot=','|
        Hash[hash.reject {|k,v| k.nil? || v.nil?}.map {|k,v| [k.to_sym,v.kind_of?(String) ? v.split(pivot).compact.map(&:to_sym) : (v.kind_of?(Hash) ? deep_split(v,pivot) : v)]}]
      end
      
      define_method("deep_sym") do |hash={}|
        Hash[hash.reject {|k,v| k.nil? || v.nil?}.map {|k,v| [k.to_sym,v.kind_of?(String) ? v.to_sym : (v.kind_of?(Hash) ? deep_sym(v) : (v.kind_of?(Array) ? v.compact.map(&:to_sym) : v))]}]
      end
      
      define_method("force_array") do |obj|
        obj.kind_of?(Array) ? obj : (obj.kind_of?(Hash) ? obj.keys : (obj==nil ? [] : [obj]))
      end
      
      define_method("hash_for") do |obj|
        if obj.kind_of?(Hash)
          hash = obj
        elsif obj.kind_of?(Array)
          hash = Hash[obj.map {|e| [e,{}]}]
        elsif obj.kind_of?(String)
          hash = Hash[obj.split(',').map {|e| [e,{}]}]
        else
          hash = {}
        end
        hash
      end
      
      define_method("required_fields") do
        object.to_s.capitalize.constantize.accessible_attributes.select {|e| is_required_column?(e)}
      end
      
      define_method("is_time_column?") do |column|
        object.to_s.capitalize.constantize.columns.select {|e| e.name==column.to_s}.first.type == :timestamp rescue false
      end
      
      define_method("is_boolean_column?") do |column|
        object.to_s.capitalize.constantize.columns.select {|e| e.name==column.to_s}.first.type == :boolean rescue false
      end
      
      define_method("is_required_column?") do |column|
        object.to_s.capitalize.constantize.validators_on(column).map(&:class).include?(ActiveModel::Validations::PresenceValidator)
      end
    end

  end
  
end
