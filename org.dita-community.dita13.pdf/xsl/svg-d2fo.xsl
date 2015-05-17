<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="2.0"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:svg="http://www.w3.org/2000/svg"
  xmlns:fo="http://www.w3.org/1999/XSL/Format"
  exclude-result-prefixes="xs"
>  
    
 <!-- ======================================================= 
   
      FO output support for the DITA 1.3 SVG domain
   
      ======================================================= -->
   
  <xsl:template match="*[contains(@class, ' svg-d/svg-container ')]">
    <xsl:param name="doDebug" as="xs:boolean" tunnel="yes" select="false()"/>

    <xsl:apply-templates>
      <xsl:with-param name="doDebug" as="xs:boolean" tunnel="yes" select="$doDebug"/>
    </xsl:apply-templates>
  </xsl:template>  
  
  
  <xsl:template match="svg:svg">
    <xsl:param name="doDebug" as="xs:boolean" tunnel="yes" select="false()"/>
    
    <!-- As of 17 May 2015 there is no way in DITA 1.3 to explicitly specify the 
         desired width and height of an SVG where the SVG does not specify an
         absolute width and height itself (that is, the graphic should be scaled
         to fit the current viewport, which in the case of FO is the current
         containing fo:block.
         
         Exploring ways to address this in the 1.3 design but until then it's
         not clear what the right thing to do is.
         
         AXF appears to follow the SVG spec and scales the SVG to fit the
         FO width (e.g., the width of the current column). FOP and Batik
         (and browsers I've tested) appear to make the viewport equal
         to the specified viewBox in pixels, but I can't find support for
         that behavior in the SVG spec.
      -->
    
    <fo:instream-foreign-object>
      <xsl:apply-templates mode="svg:copy-svg" select=".">
        <xsl:with-param name="doDebug" as="xs:boolean" tunnel="yes" select="$doDebug"/>
      </xsl:apply-templates>
    </fo:instream-foreign-object>    
  </xsl:template>
  
  <xsl:template mode="svg:copy-svg" match="svg:*">
    <xsl:param name="doDebug" as="xs:boolean" tunnel="yes" select="false()"/>

    <!-- NOTE: It appears that at least Antenna House requires that the svg: prefix be used
               on the elements: just having the SVG namespace does not appear to be enough.
      -->
    <xsl:element name="{concat('svg:', local-name(.))}">
      <xsl:apply-templates select="@*,node()" mode="#current">
        <xsl:with-param name="doDebug" as="xs:boolean" tunnel="yes" select="$doDebug"/>
      </xsl:apply-templates>
    </xsl:element>
    
  </xsl:template>
  
  <xsl:template mode="svg:copy-svg" match="*" priority="-1">
    <xsl:param name="doDebug" as="xs:boolean" tunnel="yes" select="false()"/>
    <xsl:apply-templates select="." mode="svg:non-svg-in-svg">
      <xsl:with-param name="doDebug" as="xs:boolean" tunnel="yes" select="$doDebug"/>
    </xsl:apply-templates>
  </xsl:template>
  
  <xsl:template mode="svg:non-svg-in-svg" match="*">
    <xsl:param name="doDebug" as="xs:boolean" tunnel="yes" select="false()"/>
    <!-- By default, ignore non-SVG elements within SVG -->
  </xsl:template>
  
  <xsl:template mode="svg:copy-svg" match="@* | processing-instruction() | text()">
    <xsl:param name="doDebug" as="xs:boolean" tunnel="yes" select="false()"/>
    <xsl:sequence select="."/>
  </xsl:template>

  
</xsl:stylesheet>
