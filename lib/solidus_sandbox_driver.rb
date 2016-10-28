class SolidusSandboxDriver < RailsDriver
  def perform
    extract_csrf_token
    extract_product_url
    extract_variant_id

    add_to_cart

    start_checkout
    get_state_id

    address_step
    delivery_step
    payment_step
    confirm_step
  end

  def extract_csrf_token
    extract css: 'meta[name=csrf-token]', name: 'authenticity_token', attribute: :content
  end

  def extract_product_url
    visit '/', name: 'home#index' do
      extract css: '#products a', name: 'product_url', attribute: :href, match_number: 0
    end
  end

  def extract_variant_id
    visit '${product_url}', name: 'product#show' do
      extract css: 'input[name=variant_id]', name: 'variant_id', attribute: :value, match_number: 0
    end
  end

  def add_to_cart
    post '/orders/populate', {
      'variant_id'         => '${variant_id}',
      'quantity'           => '1'
    }
  end

  def start_checkout
    visit '/checkout'
    put '/checkout/registration', {'order' => { 'email' => 'test@example.com'}, "commit" => "Continue" } do
      extract xpath: '//select[@name="order[bill_address_attributes][country_id]"]/option[text()="United States of America"]/@value', name: 'country_id', tolerant: true
    end
  end

  def get_state_id
    visit '/api/states?country_id=${country_id}' do
      extract name: 'state_id', json: "$.states[?(@.name=='New York')].id"
    end
  end

  def address_step
    patch '/checkout/update/address', order: {
      bill_address_attributes: {
        firstname: 'DeeDee',
        lastname: 'Ramone',
        address1: '53rd & 3rd',
        city: 'New York',
        country_id: '${country_id}',
        state_id: '${state_id_1}',
        zipcode: '10001',
        phone: '5555555555'
      },
      use_billing: 1
    } do
      extract css: 'input[name="order[shipments_attributes][0][selected_shipping_rate_id]"]', name: 'shipping_method_id', attribute: :value, match_number: 0
      extract css: 'input[name="order[shipments_attributes][0][id]"]', name: 'shipment_id', attribute: :value, match_number: 0
    end
  end

  def delivery_step
    patch '/checkout/update/delivery', order: {
      shipments_attributes: [
        {
          id: '${shipment_id}',
          selected_shipping_rate_id: '${shipping_method_id}'
        }
      ]
    }
  end

  def payment_step
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
  end

  def confirm_step
    patch '/checkout/update/confirm' do
      response_assertion contains: 'Your order has been processed successfully', scope: :parent
    end
  end
end
