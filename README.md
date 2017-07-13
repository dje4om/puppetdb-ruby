# puppetdb-ruby

a simple gem for interacting with the
[PuppetDB](https://github.com/puppetlabs/puppetdb) API.

This library was migrated from [puppetlabs](https://github.com/puppetlabs)
ownership to VoxPupuli on 19 October 2016.

## Installation

gem install puppetdb-ruby

## Usage

```ruby
require 'puppetdb'

# Defaults to latest API version.

# non-ssl
client = PuppetDB::Client.new({:server => 'http://localhost:8080'})

# ssl
client = PuppetDB::Client.new({
    :server => 'https://localhost:8081',
    :puppetdb_majversion => '4', # optional
    :pem    => {
        'key'     => "keyfile",
        'cert'    => "certfile",
        'ca_file' => "cafile"
    }})

response = client.request(
  'nodes',
  [:and,
    [:'=', ['fact', 'kernel'], 'Linux'],
    [:>, ['fact', 'uptime_days'], 30]
  ],
  {:limit => 10}
)

nodes = response.data

# queries are composable

uptime = PuppetDB::Query[:>, [:fact, 'uptime_days'], 30]
redhat = PuppetDB::Query[:'=', [:fact, 'osfamily'], 'RedHat']
debian = PuppetDB::Query[:'=', [:fact, 'osfamily'], 'Debian']

client.request uptime.and(debian)
client.request uptime.and(redhat)
client.request uptime.and(debian.or(redhat))
```
## Parameters

* puppetdb_majversion
optional
type: string
default: use the latest uri scheme : /pdb/query/v4/<endpoint>

use right uri scheme depending on major PuppetDB version

For PuppetDB 2.x :
```
puppetdb_majversion: "2"
```
This allow retro compat for existing scripts by adding this parameter to you PuppetDB::Client object

For PuppetDB > 2.x:
do not set parameter is recommended way

## Tests

bundle install
bundle exec rspec

## Issues & Contributions

File issues or feature requests using [GitHub
issues](https://github.com/voxpupuli/puppetdb-ruby/issues).

If you are interested in contributing to this project, please see the
[Contribution Guidelines](CONTRIBUTING.md)

## Authors

This module was donated to VoxPupuli by Puppet Inc on 10-19-2016.

Nathaniel Smith <nathaniel@puppetlabs.com>
Lindsey Smith <lindsey@puppetlabs.com>
Ruth Linehan <ruth@puppetlabs.com>

## License

See LICENSE.
