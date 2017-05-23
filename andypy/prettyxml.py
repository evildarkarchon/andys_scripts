import xml.dom.minidom as minidom
import lxml.etree as etree

def prettify_xml(input_xml, parser='minidom'):
    if 'minidom':
        try:
            out = minidom.parse(input_xml)
        except OSError:
            out = minidom.parseString(input_xml)
        else:
            return out.toprettyxml()
    elif 'lxml':
        try:
            out = etree.parse(input_xml)
        except OSError:
            out = etree.fromstring(input_xml)
        else:
            return etree.tostring(out, pretty_print=True)
