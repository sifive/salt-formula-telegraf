{% from "telegraf/map.jinja" import telegraf_grains with context %}
{%- set agent = telegraf_grains.telegraf.get('agent', {}) %}
{%- if agent.get('enabled', False) %}

telegraf_packages_agent:
  pkg.installed:
    - names: {{ agent.pkgs|yaml }}

telegraf_config_agent:
  file.managed:
    - name: {{ agent.dir.config }}/telegraf.conf
    - source: salt://telegraf/files/telegraf.conf
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - require:
      - pkg: telegraf_packages_agent
    - watch_in:
      - service: telegraf_service_agent
    - context:
      agent: {{ agent }}

config_d_dir_agent:
  file.directory:
    - name: {{agent.dir.config_d}}
    - makedirs: True
    - mode: 755
    - require:
      - pkg: telegraf_packages_agent

{%- for name,instances in agent.input.iteritems() %}
{%- for instance,values in instances.iteritems() %}

{%- if values is not mapping or values.get('enabled', True) %}
input_{{ name }}_{{ instance }}_agent:
  file.managed:
    - name: {{ agent.dir.config_d }}/input-{{ name }}-{{ instance }}.conf
    - source:
{%- if values.template is defined %}
      - salt://{{ values.template }}
{%- endif %}
      - salt://telegraf/files/input/{{ name }}.conf
      - salt://telegraf/files/input/generic.conf
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - require:
      - pkg: telegraf_packages_agent
      - file: config_d_dir_agent
    - require_in:
      - file: config_d_dir_agent_clean
    - watch_in:
      - service: telegraf_service_agent
    - defaults:
        name: {{ name }}
        instance: {{ instance }}
{%- if values is mapping %}
        values: {{ values }}
{%- else %}
        values: {}
{%- endif %}

{%- if name in ('ceph', 'docker', 'haproxy') %}
telegraf_user_in_group_{{ name }}:
  user.present:
    - name: telegraf
    - optional_groups:
      - {{ name }}
    - require:
      - pkg: telegraf_packages_agent
{%- endif %}

{%- endif %}

{%- endfor %}
{%- endfor %}

{%- for name,instances in agent.output.iteritems() %}
{%- for instance,values in instances.iteritems() %}

output_{{ name }}_{{ instance }}_agent:
  file.managed:
    - name: {{ agent.dir.config_d }}/output-{{ name }}-{{ instance }}.conf
    - source: salt://telegraf/files/output/{{ name }}.conf
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - require:
      - pkg: telegraf_packages_agent
      - file: config_d_dir_agent
    - require_in:
      - file: config_d_dir_agent_clean
    - watch_in:
      - service: telegraf_service_agent
    - defaults:
        name: {{ name }}
        instance: {{ instance }}
{%- if values is mapping %}
        values: {{ values }}
{%- else %}
        values: {}
{%- endif %}

{%- endfor %}
{%- endfor %}

config_d_dir_agent_clean:
  file.directory:
    - name: {{agent.dir.config_d}}
    - clean: True
    - require_in:
      - service: telegraf_service_agent


telegraf_service_agent:
  service.running:
    - name: telegraf
    - enable: True
    {%- if grains.get('noservices') %}
    - onlyif: /bin/false
    {%- endif %}

{%- endif %}
