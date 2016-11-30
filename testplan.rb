require 'ruby-jmeter'
require_relative 'lib/rails_driver'
require_relative 'lib/solidus_sandbox_driver'

class CandleScienceDriver < SolidusSandboxDriver
  def perform
    extract_csrf_token

    sign_up

    extract_product_url
    extract_variant_id

    add_to_cart
    start_checkout
    get_state_id

    address_step
    delivery_step
    debug_sampler
    payment_step
    confirm_step
  end

  def sign_up
    user_parameters names: ['email', 'password'],
      thread_values: {
        user_1: [
          '${__RandomString(10,abcdefghijklmnopqrstuvwxyz,)}@example.com',
          '${__RandomString(20,abcdefghijklmnopqrstuvwxyz,)}'
        ],
      },
      per_iteration: true

    post '/signup',
      'spree_user[email]'                 => '${email}',
      'spree_user[password]'              => '${password}',
      'spree_user[password_confirmation]' => '${password}' do
      extract css: 'div[class^="dropdown"] div[class^="header_and_listing"] li > a',
              name: 'category',
              attribute: 'href',
              match_number: 0
    end
  end

  def extract_product_url
    visit '${category}', name: 'category_page' do
      extract css: 'article.product a', name: 'product_url', attribute: :href, match_number: 0
    end
  end

  def extract_variant_id
    visit '${product_url}', name: 'product#show' do
      extract css: 'input[name="variant_id"]', name: 'variant_id', attribute: :value, match_number: 0
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
    } do
      extract xpath: '//label[contains(., "Faux Credit Card")]/input/@value',
              name: 'payment_method_id',
              tolerant: true
    end
  end

  def payment_step
    patch '/checkout/update/payment', {
      order: {
        payments_attributes: [payment_method_id: '${payment_method_id}']
      },
      payment_source: {
        '${payment_method_id}' => {
          name: 'DeeDee Ramone',
          number: '4111 1111 1111 1111',
          expiry: '11 / 25',
          verification_value: '123'
        }
      }
    }
  end

  def add_to_cart
    post '/orders/populate', {
      'variant_id'         => '${variant_id}',
      'quantity'           => '1'
    } do
      extract css: '#order_line_items_attributes_0_id', name: 'line_item_id', attribute: :value, match_number: 0
    end
  end

  def address_step
    patch '/checkout/update/address', order: {
      bill_address_attributes: {
        firstname: 'DeeDee',
        lastname: 'Ramone',
        address1: '53rd & 3rd',
        address2: '',
        city: 'New York',
        country_id: '${country_id}',
        state_id: '${state_id_1}',
        zipcode: '10001',
        phone: '5555555555',
        company: ''
      },
      use_billing: 1
    } do
      extract css: 'input[name="order[shipments_attributes][0][selected_shipping_rate_id]"]', name: 'shipping_method_id', attribute: :value, match_number: 0
      extract css: 'input[name="order[shipments_attributes][0][id]"]', name: 'shipment_id', attribute: :value, match_number: 0
    end
  end

  def start_checkout
    patch '/cart', "checkout" => "" do
      extract xpath: '//select[@name="order[bill_address_attributes][country_id]"]/option[text()="United States of America"]/@value', name: 'country_id', tolerant: true
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
  header name: 'X-No-Throttle', value: '533ebbcfa332680dad67f99c4439aff11d8359a7ddb50bb249e42d56eacb0da3ad2fe421315fd9a825ca6f714c806c843678a3eb602b02e416d7db8e5484da66'
  auth username: 'spree_cs_demo', password: 'k33pS3cr3tz%'
  #defaults domain: 'psychomantis.herokuapp.com', protocol: 'https', image_parser: false
  defaults domain: 'localhost', port: 3000, protocol: 'http', image_parser: false, use_concurrent_pool: 5

  cache clear_each_iteration: true
  cookies policy: "standard", clear_each_iteration: true

  threads count: 1, duration: 240, on_sample_error: 'startnextloop' do
    transaction 'checkout' do
      CandleScienceDriver.new(self).perform
    end
  end
end.run(path: File.dirname(`which jmeter`), gui: true)
