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
    def acts_as_service(object,options={})

      before_filter :assign_new_instance, only: :create
      before_filter :assign_existing_instance, only: [ :show, :update, :destroy ]
      before_filter :assign_collection, only: [ :index, :count ]
      before_filter :did_assign_collection, only: [ :index, :count ]

      define_method("index") do
        respond_to do |format|
          format.json { render json: @collection.to_json(merge_options(options[:index])) }
          format.xml  { render xml: @collection.to_xml(merge_options(options[:index])) }
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
            format.json { render json: @instance }
            format.xml  { render xml: @instance }
          else
            format.json { render json: { errors: @instance.errors.full_messages }, status: :unprocessable_entity }
            format.xml  { render xml: { errors: @instance.errors.full_messages }, status: :unprocessable_entity }
          end
        end
      end

      define_method("show") do
        respond_to do |format|
          format.json { render json: @instance.to_json(merge_options(options[:show])) }
          format.xml  { render xml: @instance.to_xml(merge_options(options[:show])) }
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

      # query string params can be given in the following formats:
      # only=field1,field2
      # except=field1,field2
      # include=assoc1
      # 
      # if an included association is present, only and except params can be nested
      # include[user][except]=encrypted_password
      # include[user][only][]=first_name&include[user][only][]=last_name
      define_method("merge_options") do |options={}|
        merged_options = options || {}
        for key in [:only, :except, :include]
          opts = {key => params[key]} if params[key]
          merged_options = merged_options.merge(opts) if opts
        end
        puts "options before split: #{merged_options}"
        merged_options = deep_split(merged_options)
        puts "options after split: #{merged_options}"
        return merged_options
      end
      
      define_method("assign_existing_instance") do
        @instance = object.to_s.camelize.constantize
        if params[:include].kind_of?(Hash)
          @instance = @instance.includes(params[:include].keys)
        end
        if params[:include].kind_of?(String)
          @instance = @instance.includes(params[:include].split(",").map(&:to_sym))
        end
        @instance = @instance.find(params[:id])
      end
      
      define_method("assign_new_instance") do
        @instance = object.to_s.camelize.constantize.new(params[object])
      end
      
      define_method("assign_collection") do
        @collection = object.to_s.camelize.constantize
        if params[:include].kind_of?(Hash)
          for assoc in params[:include].keys
            @collection = @collection.includes(assoc.to_sym)
          end
        end
        if params[:include].kind_of?(String)
          @collection = @collection.includes(params[:include].split(",").map(&:to_sym))
        end
        for clause in (params[:where].keys rescue [])
          puts "where #{clause} => #{params[:where][clause]}"
          @collection = @collection.includes(clause).where(clause => params[:where][clause])
        end
      end
      
      # designed to traverse an entire hash, replacing delimited strings with arrays of symbols
      define_method("deep_split") do |hash={},pivot=','|
        Hash[hash.map {|k,v| [k.to_sym,v.kind_of?(String) ? v.split(pivot).map(&:to_sym) : (v.kind_of?(Hash) ? deep_split(v,pivot) : v)]}]
      end
    end

  end
  
end
