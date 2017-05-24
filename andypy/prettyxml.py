import xml.dom.minidom as minidom
try:
    import lxml.etree as etree
except ImportError:
    lxml_present = False
else:
    lxml_present = True

def prettify_xml(input_xml, parser='minidom'):
    if parser is 'minidom':
        try:
            out = minidom.parse(input_xml)
        except OSError:
            out = minidom.parseString(input_xml)
        else:
            return out.toprettyxml()
    elif lxml_present and parser is 'lxml':
        try:
            out = etree.parse(input_xml)  # pylint:disable=no-member
        except OSError:
            out = etree.fromstring(input_xml)  # pylint:disable=no-member
        else:
            return etree.tostring(out, pretty_print=True) # pylint:disable=no-member
