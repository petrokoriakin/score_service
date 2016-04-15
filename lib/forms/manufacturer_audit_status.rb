class Forms::ManufacturerAuditStatus < Forms::Base

  def initialize(model = nil, params = nil, account = nil, collection = [])
    super
    assign_attributes
    build_email
  end

  def assign_attributes
    model.name = params[:name]
  end

  def persist!
    if model.changes["name"]
      collection.each do |status|
        status.update_attribute(:name, model.name) if (status.weight / 10) == (model.weight / 10)
      end
    end
    model.save!
  end

end
