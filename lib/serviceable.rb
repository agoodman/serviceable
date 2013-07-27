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
          format.json { head :ok }
          format.xml  { head :ok }
        end
      end

      define_method("merge_options") do |options={}|
        merged_options = options || {}
        for key in [:only, :except]
          merged_options = merged_options.merge({key => params[key].split(",")}) if params[key]
        end
        return merged_options
      end
      
      define_method("assign_existing_instance") do
        eval "@#{object} = object.to_s.camelize.constantize.find(params[:id])"
      end
      
      define_method("assign_new_instance") do
        eval "@#{object} = object.to_s.camelize.constantize.new(params[:#{object}])"
      end
      
      define_method("assign_instances") do
        eval "@#{object.to_s.pluralize} = object.to_s.camelize.constantize.scoped"
      end
    end
      
  end
  
end
