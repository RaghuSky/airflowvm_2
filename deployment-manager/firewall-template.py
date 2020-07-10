def generate_config(context):
    """
    Deny traffic from all IP addresses across all protocols and ports, but allow all incoming traffic from Sky.
    Note: Airflow specifically requires traffic to/from ports 8080 (Airflow webserver) and 5432 (PostgreSQL).
    """
    resources = [
        {
            'name': context.env['deployment'] + '-deny-all',
            'type': 'compute.v1.firewall',
            'properties': {
                'description': 'Block traffic from all IP addresses across all protocols and ports.',
                'network': 'global/networks/default',
                'priority': 500,
                'sourceRanges': ['0.0.0.0/0'],
                'targetTags': [context.env['deployment'] + '-vm'],
                'denied': [
                    {
                        'IPProtocol': 'all'
                    }
                ]
            }
        },
        {
            'name': context.env['deployment'] + '-allow-sky',
            'type': 'compute.v1.firewall',
            'properties': {
                'description': 'Allow all incoming traffic from the Sky network.',
                'network': 'global/networks/default',
                'priority': 499,
                'sourceRanges': ['90.216.150.0/24', '90.216.134.0/24'],
                'targetTags': [context.env['deployment'] + '-vm'],
                'allowed': [
                    {
                        'IPProtocol': 'all'
                    }
                ]
            }
        },
        {
            'name': context.env['deployment'] + '-allow-internal',
            'type': 'compute.v1.firewall',
            'properties': {
                'description': 'Allow internal traffic between VMs.',
                'network': 'global/networks/default',
                'priority': 499,
                'sourceRanges': ['10.128.0.0/9'],
                'targetTags': [context.env['deployment'] + '-vm'],
                'allowed': [
                    {
                        'IPProtocol': 'all'
                    }
                ]
            }
        },
        {
            'name': context.env['deployment'] + '-allow-google',
            'type': 'compute.v1.firewall',
            'properties': {
                'description': 'Allow SSH (e.g. browser based SSH) from the Google network.',
                'network': 'global/networks/default',
                'priority': 499,
                'sourceRanges': ['74.125.0.0/16'],
                'targetTags': [context.env['deployment'] + '-vm'],
                'allowed': [
                    {
                        'IPProtocol': 'tcp',
                        'ports': [22]
                    }
                ]
            }
        }
    ]
    return {'resources': resources}