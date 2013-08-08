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

      before_filter :assign_new_instance, :only => :create
      before_filter :assign_existing_instance, :only => [ :show, :update, :destroy ]
      before_filter :assign_instances, :only => :index

      define_method("index") do
        respond_to do |format|
          format.json { eval "render :json => @#{object.to_s.pluralize}.to_json(merge_options(options[:index]))" }
          format.xml  { eval "render :xml => @#{object.to_s.pluralize}.to_xml(merge_options(options[:index]))" }
        end
      end

      define_method("create") do
        respond_to do |format|
          if eval "@#{object}.save"
            format.json { eval "render :json => @#{object}" }
            format.xml  { eval "render :xml => @#{object}" }
          else
            format.json { eval "render :json => { :errors => @#{object}.errors.full_messages }, :status => :unprocessable_entity" }
            format.xml  { eval "render :xml => { :errors => @#{object}.errors.full_messages }, :status => :unprocessable_entity" }
          end
        end
      end

      define_method("show") do
        respond_to do |format|
          format.json { eval "render :json => @#{object}.to_json(options[:show])" }
          format.xml  { eval "render :xml => @#{object}.to_xml(options[:show])" }
        end
      end

      define_method("update") do
        respond_to do |format|
          if eval "@#{object}.update_attributes(params[object])"
            format.json { head :ok }
            format.xml  { head :ok }
          else
            format.json { eval "render :json => { :errors => @#{object}.errors.full_messages }, :status => :unprocessable_entity" }
            format.xml  { eval "render :xml => { :errors => @#{object}.errors.full_messages }, :status => :unprocessable_entity" }
          end
        end
      end

      define_method("destroy") do
        eval "@#{object}.destroy"

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
        instance = object.to_s.camelize.constantize
        instance = instance.includes(params[:include]) if params[:include]
        instance = instance.find(params[:id])
        eval "@#{object} = instance"
      end
      
      define_method("assign_new_instance") do
        instance = object.to_s.camelize.constantize.new(params[object])
        eval "@#{object} = instance"
      end
      
      define_method("assign_instances") do
        collection = object.to_s.camelize.constantize
        collection = collection.includes(params[:include]) if params[:include]
        eval "@#{object.to_s.pluralize} = collection"
      end
      
      # designed to traverse an entire hash, replacing delimited strings with arrays of symbols
      define_method("deep_split") do |hash={},pivot=','|
        Hash[hash.map {|k,v| [k.to_sym,v.kind_of?(String) ? v.split(pivot).map(&:to_sym) : (v.kind_of?(Hash) || v.kind_of?(Array) ? deep_split(v,pivot) : v)]}]
      end
    end

  end
  
end
