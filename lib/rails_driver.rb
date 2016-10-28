class RailsDriver < SimpleDelegator
  private

  def put(url, params={}, options={}, &block)
    post(url, {'_method' => 'put'}.merge(params), options, &block)
  end

  def patch(url, params={}, options={}, &block)
    post(url, {'_method' => 'patch'}.merge(params), options, &block)
  end

  def post(url, params={}, options={}, &block)
    block ||= ->{}
    params = params.merge('authenticity_token' => '${__urlencode(${authenticity_token})}')
    options = options.merge(fill_in: Hash[to_query(params)])
    submit(url, options) do
      instance_exec(&block)
    end
  end

  def to_query(value, base=nil)
    case value
    when Hash
      value.flat_map do |k,v|
        to_query(v, append_key(base, k))
      end
    when Array
      value.flat_map do |v|
        to_query(v, "#{base}[]")
      end
    when nil
      []
    else
      [[base, value]]
    end
  end

  def append_key(base, new)
    base ? "#{base}[#{new}]" : new
  end
end
