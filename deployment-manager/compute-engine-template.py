def generate_config(context):
    """Creates the Compute Engine with default network and firewall."""

    properties = {
        'projectId': context.properties['projectId'],
        'zone': context.properties['zone'],
        'etlApiVm': context.properties['etlApiVm'],
        'machineType': context.properties['machineType'],
        'secretsBucket': context.properties['secretsBucket'],
        'startupBucket': context.properties['startupBucket'],
        'repo': context.properties['repo']}

    if 'tag' in context.properties:
        properties['tag'] = context.properties['tag']
    else:
        if 'branch' in context.properties:
            properties['branch'] = context.properties['branch']

    resources = [{
        'name': 'vm-1',
        'type': 'vm-template.py',
        'properties': properties
    },{
        'name': 'firewall-1',
        'type': 'firewall-template.py'
    }
    ]
    return {'resources': resources}