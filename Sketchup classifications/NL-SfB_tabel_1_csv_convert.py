import csv
from lxml import etree
import shutil
import sys


def main(csv_file_path):
    """
    Convert a NL-SfB tabel 1 CSV file to a Sketchup SKC file.

    Args:
      csv_file_path (str): The path to the CSV file.

    Returns:
      None
    """
    # Define the file paths
    csv_file_path = sys.argv[1]
    xsd_file_path = './NL-SfB tabel 1/Schemas/NL-SfB tabel 1.xsd'
    xsd_filter_file_path = './NL-SfB tabel 1/Schemas/NL-SfB tabel 1.xsd.filter'
    archive_name = 'NL-SfB tabel 1'
    archive_dir = './NL-SfB tabel 1'
    archive_path = '../src/bt_ifcmanager/classifications/NL-SfB tabel 1.skc'

    # Define the namespaces
    ns = {'xs': "http://www.w3.org/2001/XMLSchema"}

    # Open the CSV file
    with open(csv_file_path, 'r') as f:
        reader = csv.DictReader(f, delimiter=';')
        next(reader)  # Skip the header row

        # Create the root element
        root = etree.Element('{%s}schema' % ns['xs'], nsmap=ns)

        # Open the text file
        with open(xsd_filter_file_path, 'w', encoding='utf-8') as txt_file:

            # Iterate over the rows of the CSV
            for row in reader:
                # Create an 'xs:element' for each row
                element_name = row['NL/SfB_fullname_nl']
                element = etree.SubElement(
                    root, '{%s}element' % ns['xs'], name=element_name)

                # Write the element name to the text file, skipping if "-gereserveerd-" is in the name or 'Class-codenotatie' length is not 5
                if "-gereserveerd-" not in element_name and len(row['Class-codenotatie']) == 5:
                    txt_file.write(element_name + '\n')

                # Create 'xs:attribute' for 'Identification'
                attribute_identification = etree.SubElement(
                    element, '{%s}attribute' % ns['xs'], name='Identification')
                simple_type_identification = etree.SubElement(
                    attribute_identification, '{%s}simpleType' % ns['xs'])
                restriction_identification = etree.SubElement(
                    simple_type_identification, '{%s}restriction' % ns['xs'], base='xs:string')
                etree.SubElement(restriction_identification,
                                 '{%s}enumeration' % ns['xs'], value=row['Class-codenotatie'])

                # Create 'xs:attribute' for 'Name'
                attribute_name = etree.SubElement(
                    element, '{%s}attribute' % ns['xs'], name='Name')
                simple_type_name = etree.SubElement(
                    attribute_name, '{%s}simpleType' % ns['xs'])
                restriction_name = etree.SubElement(
                    simple_type_name, '{%s}restriction' % ns['xs'], base='xs:string')
                etree.SubElement(
                    restriction_name, '{%s}enumeration' % ns['xs'], value=row['tekst_NL-SfB'])

        # Write the XML to a file
        tree = etree.ElementTree(root)
        tree.write(xsd_file_path, pretty_print=True,
                   xml_declaration=True, encoding='UTF-8')

    # Create a zip file
    shutil.make_archive(archive_name, 'zip', archive_dir)

    # Rename the zip file to .skc
    shutil.move(archive_name + '.zip', archive_path)


if __name__ == "__main__":
    main(sys.argv[1])
