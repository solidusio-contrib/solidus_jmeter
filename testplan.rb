require 'ruby-jmeter'

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

class SolidusDriver < RailsDriver
  def perform
    extract css: 'meta[name=csrf-token]', name: 'authenticity_token', attribute: :content

    visit '/', name: 'home#index' do
      extract css: '#products a', name: 'product_url', attribute: :href, match_number: 0
    end
    visit '${product_url}', name: 'product#show' do
      extract css: 'input[name=variant_id]', name: 'variant_id', attribute: :value, match_number: 0
    end
    post '/orders/populate', {
      'variant_id'         => '${variant_id}',
      'quantity'           => '1'
    }
    visit '/checkout'
    put '/checkout/registration', order: {email: 'test@example.com'} do
      extract xpath: '//select[@name="order[bill_address_attributes][country_id]"]/option[text()="United States of America"]/@value', name: 'country_id', tolerant: true
    end
    visit '/api/states?country_id=${country_id}' do
      extract name: 'state_id', json: "$.states[?(@.name=='New York')][0].id"
    end
    patch '/checkout/update/address', order: {
      bill_address_attributes: {
        firstname: 'DeeDee',
        lastname: 'Ramone',
        address1: '53rd & 3rd',
        city: 'New York',
        country_id: '${country_id}',
        state_id: '${state_id}',
        zipcode: '10001',
        phone: '5555555555'
      },
      use_billing: 1
    } do
      extract css: 'input[name="order[shipments_attributes][0][selected_shipping_rate_id]"]', name: 'shipping_method_id', attribute: :value, match_number: 0
      extract css: 'input[name="order[shipments_attributes][0][id]"]', name: 'shipment_id', attribute: :value, match_number: 0
    end
    patch '/checkout/update/delivery', order: {
      shipments_attributes: [
        {
          id: '${shipment_id}',
          selected_shipping_rate_id: '${shipping_method_id}'
        }
      ]
    }
    patch '/checkout/update/payment', {
      order: {
        payments_attributes: [payment_method_id: 2]
      },
      payment_source: {
        2 => {
          name: 'DeeDee Ramone',
          number: '4111 1111 1111 1111',
          expiry: '11 / 25',
          verification_value: '123'
        }
      }
    }
    patch '/checkout/update/confirm' do
      response_assertion contains: 'Your order has been processed successfully', scope: :parent
    end
  end
end

test do
  aggregate_graph
  aggregate_report
  graph_results
  response_time_graph
  summary_report
  transactions_per_second name: "transactions per 30s", interval_grouping: 30000
  view_results_tree
  assertion_results

  defaults domain: 'localhost', protocol: 'http', port: 3000, download_resources: false
  #defaults domain: 'demo.solidus.io', protocol: 'https', download_resources: false, use_concurrent_pool: 5

  cache clear_each_iteration: true
  cookies

  threads count: 10, duration: 240 do
    transaction 'checkout' do
      SolidusDriver.new(self).perform
    end
  end
end.run(path: File.dirname(`which jmeter`), gui: true)
