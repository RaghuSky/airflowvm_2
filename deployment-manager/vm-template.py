COMPUTE_URL_BASE = 'https://www.googleapis.com/compute/v1/'

def generate_config(context):
    """Creates a Google Compute Engine virtual machine."""

    # Customise instance metadata
    metadata_items = [
        {
            'key': 'project-id',
            'value': context.properties['projectId']
        },
        {
            'key': 'etl-api-vm',
            'value': context.properties['etlApiVm']
        },
        {
            'key': 'startup-script-url',
            'value': 'gs://' + context.properties['startupBucket'] + '/python3.sh'
        },
        {
            'key': 'secrets-bucket',
            'value': context.properties['secretsBucket']
        },
        {
            'key': 'startup-bucket',
            'value': context.properties['startupBucket']
        },
        {
            'key': 'repo',
            'value': context.properties['repo']
        }
    ]

    if 'tag' in context.properties and context.properties['tag'] != '':
        metadata_items.append({
            'key': 'tag',
            'value': context.properties['tag']
        })

    else:
        if 'branch' in context.properties and context.properties['branch'] != '':
            metadata_items.append({
                'key': 'branch',
                'value': context.properties['branch']
            })

    resources = [{
        'name': context.env['deployment'] + '-vm',
        'type': 'compute.v1.instance',
        'properties': {
            'zone': context.properties['zone'],
            'tags': {
                'items': [context.env['deployment'] + '-vm']
            },
            'machineType': ''.join([COMPUTE_URL_BASE, 'projects/', context.env['project'],
                                    '/zones/', context.properties['zone'],
                                    '/machineTypes/', context.properties['machineType']]),
            'disks': [{
                'deviceName': 'boot',
                'type': 'PERSISTENT',
                'boot': True,
                'autoDelete': True,
                'initializeParams': {
                    'sourceImage': ''.join([COMPUTE_URL_BASE, 'projects/debian-cloud/global/images/family/debian-9'])
                }
            }],
            'metadata': {
                'items': metadata_items,
                'kind': 'compute#metadata'
            },
            'networkInterfaces': [{
                'network': '/global/networks/default',
                'accessConfigs': [{
                    'name': 'External NAT',
                    'type': 'ONE_TO_ONE_NAT'
                }]
            }],
            'serviceAccounts': [
                {
                    'email': context.env['project_number'] + '-compute@developer.gserviceaccount.com',
                    #'email': 'decis-etl-01-prod@skyuk-uk-decis-etl-01-prod.iam.gserviceaccount.com',
                    'scopes': ['https://www.googleapis.com/auth/cloud-platform']
                }
            ]
        }
    }]
    return {'resources': resources}
