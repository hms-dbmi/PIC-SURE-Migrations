use auth;

INSERT INTO termsOfService (uuid, dateUpdated, content)
	VALUES (UNHEX(REPLACE(uuid(),'-','')), CURRENT_TIMESTAMP(),
    '<div id="main-content" class="container">
   <div>
      <div id="tos">
         <div class="header-tool">Terms and Conditions of Use of the Genomic Information Commons (GIC) Portal</div>
         <br />
         <div class="tos-content">
            <div>User must select the terms and click “accept” to certify that User agrees to the Terms and Conditions of Use of the GIC Portal:</div>
            <div class="checkbox"><label><input type="checkbox" class="tosCheckbox" value="">i.User is a paid employee of a GIC member site, or, User has been granted a temporary exemption by GIC Project Director or the GIC Governance Committee.</label></div>
            <div class="checkbox"><label><input type="checkbox" class="tosCheckbox" value="">ii.User has completed all applicable required institutional certification training course(s), for example CITI training and such training is up to date or, User has been granted a temporary exemption by GIC Project Director or the GIC Governance Committee.</label></div>
            <div class="checkbox"><label><input type="checkbox" class="tosCheckbox" value="">iii. If User’s employment statuses change, User will notify User’s institutional biobank staff immediately.</label></div>
            <div class="checkbox"><label><input type="checkbox" class="tosCheckbox" value="">iv. User will not attempt to identify, or re-identify any patients contained in the aggregate data.</label></div>
            <div class="checkbox"><label><input type="checkbox" class="tosCheckbox" value="">v. User agrees to use the data and samples for research purposes only.</label></div>
            <div class="checkbox"><label><input type="checkbox" class="tosCheckbox" value="">vi. User agrees to follow all applicable terms and conditions including those applicable in the GIC Manual of Operating Procedures. User may be asked to agree to additional terms and conditions including but not limited to the GIC Publications Policy.</label></div>
            <div class="checkbox"><label><input type="checkbox" class="tosCheckbox" value="">vii. User agrees to having User’s activities monitored, stored, and used for security and for insight into how the research community uses the GIC. Activities include, but are not limited to, user logins, queries, user location, language, demographics, and device.</label></div>
            <div class="checkbox"><label><input type="checkbox" class="tosCheckbox" value="">viii. User agrees to User’s email address being added to the GIC mailing list for future communications. User can opt out at any time by emailing GIC-admins@chip.org.</label></div>
            <div class="checkbox"><label><input type="checkbox" class="tosCheckbox" value="">ix. User understands that any violation of these Terms and Conditions of Use may subject User to disciplinary action by User’s institution.</label></div>
            <div class="checkbox"><label><input type="checkbox" class="tosCheckbox" value="">x. User understands that any violation of these Terms and Conditions of Use may result in a probationary or permanent ban of access to the GIC.</label></div>
            <div class="checkbox"><label><input type="checkbox" class="tosCheckbox" value="">xi. User acknowledges and agrees that access to the GIC portal may be revoked at any time, for any reason, with or without prior notice.</label></div>
            <div class="checkbox"><label><input type="checkbox" class="tosCheckbox" value="">xii. The Terms and Conditions may be modified from time to time and continued use of the GIC is deemed acceptance by the User of such Terms and Conditions and modifications thereof.</label></div>
			<div class="checkbox"><label><input type="checkbox" class="tosCheckbox" value="">xiii. User understands that this portal enables feasibility studies in preparation for research. Research projects require active participation from local investigators and approval from a GIC Data and Sample Access Committee.</label></div>
            <button type="button" id="acceptBtn" class="btn btn-info accept-tos-button" disabled="">  <span>Accept</span> </button>
            <script>$(".tosCheckbox").on("change", function(){if ($(".tosCheckbox:checked").length == $(".tosCheckbox").length){$("#acceptBtn").prop("disabled",false);}else{$("#acceptBtn").prop("disabled", true);}});</script>
         </div>
      </div>
   </div>
</div>');
