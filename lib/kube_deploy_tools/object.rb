
class Object
  def present?
    self && to_s.strip != ''
  end

  def blank?
    !present?
  end
end

