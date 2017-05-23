import xml.dom.minidom as minidom

def prettify_xml(input_xml):
    try:
        out = minidom.parse(input_xml)
    except OSError:
        out = minidom.parseString(input_xml)
    else:
        return out.toprettyxml()
