<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl"
  xmlns:local="urn:namespace:functions:local"
  exclude-result-prefixes="xs local xd"
  version="2.0">
  <!-- ===========================================
       Functions common to the 1.3 vocabulary 
       support plugins.
       =========================================== -->
  
  <xsl:param name="tempdir" as="xs:string" select="'tempdir-not-set'"/>
  <xsl:param name="mappath" as="xs:string" select="'mappath-not-set'"/>
  
  <xsl:function name="local:getURIForKeyref" as="xs:string?">
    <xsl:param name="keyref" as="attribute(keyref)"/>
    
    <xsl:variable name="keyname" as="xs:string" 
      select="if (contains($keyref, '/'))
                 then tokenize($keyref, '/')[1]
                 else string($keyref)"
    />
    
    <!-- Get the keys.xml file and look up the key name.
      -->
    <xsl:variable name="keydefsURI" as="xs:string" 
      select="concat($tempdir, '/', 'keydef.xml')"
    />
    <xsl:variable name="keydefDoc" as="document-node()?"
      select="document($keydefsURI)"
    />
    
    <xsl:variable name="result" as="xs:string?">
      <xsl:choose>
        <xsl:when test="not($keydefDoc)">
          <xsl:message> - [WARN] local:getURIForKeyref(): Unable find keydef file at URI "<xsl:value-of select="$keydefsURI"/>"</xsl:message>
        </xsl:when>
        <xsl:otherwise>
          <xsl:variable name="keydef" as="element()*"
             select="$keydefDoc/*/keydef[@keys = $keyname]"
          />
          <!-- Make the URI absolute. If the target is a DITA document then
               can resolve relative to the keydef document (that is, in the temp
               directory), but if it's not then need to resolve relative to 
               the original map document, because the file may not have been 
               copied to the output.
            -->
          <xsl:variable name="format" as="xs:string"
            select="if ($keyref/../@format != '') 
                       then $keyref/../@format 
                       else 'dita'"
          />
          <xsl:message> + [DEBUG] local:getURIForKeyref: format="<xsl:value-of select="$format"/>"</xsl:message>
          <xsl:variable name="contextDoc" as="document-node()?"
            select="if (not($format = ('dita', 'ditamap'))) 
                       then document($mappath) 
                       else $keydefDoc"
          />
          <xsl:variable name="uri" as="xs:string?"
            select="string(resolve-uri($keydef/@href, document-uri($contextDoc)))"
          />
          <xsl:message> + [DEBUG] local:getURIForKeyref: uri="<xsl:value-of select="$uri"/>"</xsl:message>
          <xsl:sequence select="$uri"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:sequence select="$result"/>
  </xsl:function>
  
  <!-- Given an xref, resolve it to a document. 
    
    -->
  <xsl:function name="local:resolveRefToDocument" as="document-node()?">
    <xsl:param name="xref" as="element()"/>
    
    <xsl:variable name="doDebug" as="xs:boolean" select="true()"/> 
    
    <xsl:variable name="href" select="$xref/@href" as="xs:string?"/>
    <xsl:variable name="keyref" select="$xref/@keyref" as="xs:string?"/>
   
    <xsl:variable name="refContextNode" as="node()?"
      select="local:getRefContextNode($xref)"
    />
    <xsl:variable name="keyrefURI" as="xs:string?"
      select="if ($xref/@keyref) 
                 then local:getURIForKeyref($xref/@keyref) 
                 else ()"
    />
    <xsl:if test="$doDebug">
      <xsl:message> + [DEBUG] resolveRefToDocument: keyref=<xsl:value-of select="$xref/@keyref"/></xsl:message>
      <xsl:message> + [DEBUG] resolveRefToDocument: $keyrefURI="<xsl:value-of select="$keyrefURI"/>"</xsl:message>
    </xsl:if>
    
    <xsl:variable name="keyResource" as="document-node()?"
       select="local:resolveURIToDocument($refContextNode, $keyrefURI)"
    />
    <xsl:variable name="hrefResource" as="document-node()?"
       select="local:resolveURIToDocument($refContextNode, $href)"
    />

    <xsl:choose>
      <xsl:when test="$keyResource">
        <xsl:sequence select="$keyResource"/>
      </xsl:when>
      <xsl:when test="$hrefResource and not($keyref)">
        <xsl:sequence select="$hrefResource"/>
      </xsl:when>
      <xsl:when test="$keyref != '' and $hrefResource">
        <xsl:message> - [WARN] local:resolveRefToDocument(): Unable to resolve reference to key "<xsl:value-of select="$xref/@keyref"/>", using @href as fallback</xsl:message>
        <xsl:sequence select="$hrefResource"/>
      </xsl:when>
      <xsl:when test="$href and not($hrefResource)">
        <xsl:message> - [WARN] local:resolveRefToDocument(): Unable to resolve href "<xsl:value-of select="$xref/@href"/>"</xsl:message>
        <xsl:sequence select="()"/>        
      </xsl:when>
      <xsl:otherwise>
        <xsl:message> - [WARN] local:resolveRefToDocument(): No @keyref or @href</xsl:message>
        <xsl:sequence select="()"/>
      </xsl:otherwise>
    </xsl:choose>
    
  </xsl:function>
  
  <!-- Given a context element and a URI, resolve the URI relative
       to that context element and return the result, if any.
       
       NOTE: When this function is used to resolve references to
             non-DITA files the context should be the original
             source node in its source location, not the 
             temporary copy, because the OT does not copy
             non-DITA or unrecognized non-DITA file types to the
             temporary location. So SVG and MathML files will
             not be in the temporary area.
    -->
  <xsl:function name="local:resolveURIToDocument" as="document-node()?">
    <xsl:param name="context" as="element()"/>
    <xsl:param name="URI" as="xs:string?"/>
    
    <xsl:variable name="resourcePart" as="xs:string?"
      select="if (contains($URI, '#')) then substring-before($URI, '#') else $URI"
    />
    <!--        <xsl:message> + [DEBUG] svgref: Resource part = "<xsl:value-of select="$resourcePart"/>"</xsl:message>-->
    <!-- FIXME: Really need to use functions from relpath utils to do this properly -->
    <xsl:variable name="fragmentId" as="xs:string?"
      select="if (contains($URI, '#')) then substring-after($URI, '#') else ''"
    />
    <xsl:variable name="refContextNode" as="node()" 
      select="local:getRefContextNode($context)"
    />
    <xsl:variable name="resultDoc" as="document-node()?"
      select="if ($resourcePart != '') 
                 then document($resourcePart, $refContextNode) 
                 else root($refContextNode)"
    />
    
    <xsl:sequence select="$resultDoc"/>

  </xsl:function>
  
  <xsl:function name="local:getFragmentIDForXRef" as="xs:string?">
    <xsl:param name="xref" as="element()"/>
    
    <xsl:variable name="href" select="$xref/@href" as="xs:string?"/>
    <xsl:variable name="keyref" select="$xref/@keyref" as="xs:string"/>
   
    <xsl:variable name="refContextNode" as="node()?"
      select="local:getRefContextNode($xref)"
    />
    <xsl:variable name="keyrefURI" as="xs:string?"
      select="if ($xref/@keyref) 
                 then local:getURIForKeyref($xref/@keyref)
                 else ()"
    />

    <xsl:variable name="keyResource" as="document-node()?"
       select="local:resolveURIToDocument($refContextNode, $keyrefURI)"
    />
    <xsl:variable name="hrefResource" as="document-node()?"
       select="local:resolveURIToDocument($refContextNode, $href)"
    />
    
    <xsl:variable name="result" as="xs:string?">
      <xsl:choose>
        <xsl:when test="$keyResource">
          <xsl:sequence select="if (contains($keyrefURI, '#')) 
            then tokenize($keyrefURI, '#')[2]
            else ()"/>
        </xsl:when>
        <xsl:when test="$href">
          <xsl:sequence select="if (contains($href, '#')) 
            then tokenize($href, '#')[2]
            else ()"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:sequence select="()"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:sequence select="$result"/>
    
  </xsl:function>
  
  <!-- Given an element returns the appropriate element to use as the 
       context for resolving relative URIs. If the reference target
       is a DITA document, it returns the input element, otherwise
       it resolves the @xtrf value to get the original document
       that contains the input element so that references
       can be resolved relative to the original source location.
    -->
  <xsl:function name="local:getRefContextNode" as="element()">
    <xsl:param name="xref" as="element()"/>
    
    <xsl:variable name="format" as="xs:string"
        select="if ($xref/@format) then $xref/@format else 'dita'"
    />
    <xsl:variable name="xtrf" select="($xref/ancestor-or-self::*[@xtrf])[last()]/@xtrf" as="xs:string?"/>
    <xsl:message> + [DEBUG] local:getRefContextNode: xtrf="<xsl:value-of select="$xtrf"/>"</xsl:message>
    <xsl:message> + [DEBUG] local:getRefContextNode: not($format = ('dita', 'ditamap')) and $xtrf="<xsl:value-of select="not($format = ('dita', 'ditamap')) and $xtrf"/>"</xsl:message>
    <xsl:variable name="refContextNode" as="node()?"
      select="if (not($format = ('dita', 'ditamap')) and $xtrf) 
                 then document($xtrf)/* 
                 else $xref"
    />
    <xsl:sequence select="$refContextNode"/>
  </xsl:function>
  
</xsl:stylesheet>