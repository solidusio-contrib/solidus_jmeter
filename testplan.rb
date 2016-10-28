require 'ruby-jmeter'
require_relative 'lib/rails_driver'
require_relative 'lib/solidus_sandbox_driver'

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
  cookies policy: "standard", clear_each_iteration: true

  threads count: 10, duration: 240 do
    transaction 'checkout' do
      SolidusSandboxDriver.new(self).perform
    end
  end
end.run(path: File.dirname(`which jmeter`), gui: true)
