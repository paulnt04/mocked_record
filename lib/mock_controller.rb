class AuditedController

  def deleted_index
    @render_by_column = false
    if defined?(admin_columns)
      @render_by_column = true
      @columns = admin_columns
      @columns << {:method => 'last_audit', :human_name => 'Log Status', :type => 'comment'}
    end
    audits = Audit.find_by_sql("SELECT a1.* FROM `audits` a1 LEFT JOIN audits a2 ON (a1.auditable_id = a2.auditable_id AND a1.auditable_type = a2.auditable_type AND a1.id < a2.id) WHERE a2.id IS NULL AND a1.created_at #{(90.days.ago.midnight..1.day.from_now.midnight).to_s(:db)} AND a1.action = 'destroy' AND a1.auditable_type = '#{params[:controller].singularize.camelize}' ORDER BY created_at DESC")
    @records = audits.collect{|audit| params[:controller].singularize.camelize.constantize.mock({:audit => audit})}
    respond_to do |format|
      format.html { render 'mocks/index.html' }
    end
  end

  def deleted_show
    instance_variable_set("@#{params[:controller].singularize}", params[:controller].singularize.camelize.constantize.mock(params[:id].to_i))
    respond_to do |format|
      #format.html { render 'lists/deleted_item' }
      format.html do
        if File.exist?("#params[:controller]/show.html.erb")
          render "#{params[:controller]}/show"
        else
          render "mocks/show"
        end
      end
    end
  end

end
