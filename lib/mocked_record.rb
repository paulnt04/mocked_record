class AuditedRecord < ActiveRecord

  self.abstract_class = true

  def self.mock params
    begin
      mock = self.new
      if !params[:audit].blank? && params.class.to_s =~ /hash/i
        audit = params[:audit]
      elsif !params[:id].blank? && params.class.to_s =~ /hash/i
        if !params[:version].blank?
          audit = Audit.find_by_auditable_type_and_auditable_id_and_version(self.to_s.underscore,params[:id],params[:version])
        else
          audit = Audit.find_by_auditable_type_and_auditable_id(self.to_s.underscore,params[:id], :order => "version DESC")
        end
      elsif !params.blank? && params.class.to_s =~ /Fixnum/i
        audit = Audit.find_by_auditable_type_and_auditable_id(self.to_s.underscore,params.to_i, :order => "version DESC")
      else
        raise "Need to specify id or audit object."
      end
      if (self.find(audit.auditable_id.to_i) rescue false)
        self.find(audit.auditable_id.to_i).attributes.reject{|k,v| k == "id"}.each do |attribute, value|
          mock[attribute.to_sym] = value
        end
      end
      records = Audit.find_all_by_auditable_id_and_auditable_type(audit.auditable_id,audit.auditable_type, :order => "version ASC")
      records.reject!{|record| record.version > audit.version }
      records.each do |record|
        record.audited_changes.each do |key,value|
          if record.action == "update"
            mock[key.to_sym] = value[1]
          else
            mock[key.to_sym] = value
          end
        end
      end
      mock[:id] = audit.auditable_id
      if params[:associated] == true
        mock.class.reflect_on_all_associations.each do |association|
        begin
          # keys = association.primary_key_name.split(/_and_/)
          case association.macro.to_s
            when /has_and_belongs_to_many/
              nil # Associations are not audited and therefore lost when deleted.
            when /belongs_to/
              conditions = ["#{association.primary_key_name} = ?", mock.send(association.primary_key_name)]
            when /(has_one|has_many)/
              conditions = ["#{association.primary_key_name} = ?",mock.id]
          end
          if !conditions.nil?
            klass_results = association.klass.where(conditions)
            if !klass_results.blank? && association.macro.to_s =~ /has_one/
              klass_results = klass_results[0]
            end
            if !klass_results.blank?
              if association.macro.to_s =~ /has_one/
                klass_results = klass_results[0]
              end
              assoc_object = klass_results
            end
            if klass_results.blank? && !(association.macro.to_s =~ /has_and_belongs_to_many/)
               case association.macro.to_s
                 when /belongs_to/
                   _audits = Audit.find_by_auditable_type_and_auditable_id(association.klass.to_s,mock.send(association.primary_key_name))
                 when /(has_one|has_many)/
                   _audits = Audit.find_all_by_auditable_type(association.klass.to_s).select{|_audit| (_audit.audited_changes[association.primary_key_name] == mock.id) || ((_audit.audited_changes[association.primary_key_name][1] == mock.id) rescue false)}
               end
               assoc_object = _audits.inject([]){|result,_audit| result << association.klass.mock({:audit => _audit, :associated => false}) unless result.find{|record| record.id == _audit.auditable_id}; result}
               if association.macro.to_s =~ /has_one/
                 assoc_object = assoc_object[0]
               end
            end
            if !assoc_object.blank?
              mock.send(association.name.to_s + "=", assoc_object)
            end
          end
        rescue
          nil
        end
      end
      end
      mock.audits = Audit.find_all_by_auditable_type_and_auditable_id(audit.auditable_type, audit.auditable_id, :order => 'version ASC')
      return mock
    rescue
      if (audit.id rescue false)
        raise "Error when generating mocked_record for #{audit.auditable_type} with id=#{audit.id}"
      else
        raise "Error when generating mocked_record"
      end
    end
  end

  def save
    if self.mocked_record?
      raise TypeError, "MockedRecord: Method undefined."
    else
      super
    end
  end

  def last_audit format="txt"
    audit = Audit.find_by_auditable_type_and_auditable_id(self.class.to_s,self.id, :order => "created_at DESC")
    case format
    when /hash/i
      return audit
    when /t(e?)xt/i
      return "#{audit.action.humanize}#{audit.action == "destroy" ? "ed" : "d"} by #{User.find(audit.user_id).full_name rescue 'Unknown User'} on #{audit.created_at.localtime.strftime('%m/%d/%Y at %H:%M')}"
    else
      return audit
    end
  end

  def mocked_record?
    (self.new_record? && self.id) ? true : false
  end

  def restore

  end

  def self.restore(params)

  end

  def revert(params)

  end
end
